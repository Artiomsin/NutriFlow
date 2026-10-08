import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {

    let todayFoodVM: TodayFoodViewModel
    let waterVM: WaterViewModel
    let goalsVM: GoalsViewModel
    let activityVM: ActivityViewModel
    let workoutVM: WorkoutViewModel
    let sleepVM: SleepViewModel
    
    var dailySummaryState: DailySummaryState = .idle

    var userGoals: UserGoals? {
        if case .loaded(let goals) = goalsVM.state { return goals }
        return nil
    }

    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let dailySummaryService: DailySummaryServiceProtocol
    @ObservationIgnored let foodService: FoodServiceProtocol
    @ObservationIgnored private let cacheService: CacheService?
    @ObservationIgnored private let activitySync: ActivitySyncProtocol
    @ObservationIgnored private let progressRefreshState: ProgressRefreshState?
    @ObservationIgnored private var lastGoalsRevision: UInt?
    @ObservationIgnored private var dashboardSummaryTask: Task<Void, Never>?
    @ObservationIgnored private var dashboardSummaryGeneration = 0

    
    @ObservationIgnored private var lastForegroundRefreshAt: Date?
    private static let foregroundDedupeWindow: TimeInterval = 2

    init(
        coordinator: AppCoordinator,
        dailySummaryService: DailySummaryServiceProtocol,
        foodService: FoodServiceProtocol,
        todayFoodVM: TodayFoodViewModel,
        waterVM: WaterViewModel,
        goalsVM: GoalsViewModel,
        activityVM: ActivityViewModel,
        workoutVM: WorkoutViewModel,
        sleepVM: SleepViewModel,
        activitySync: ActivitySyncProtocol,
        
        cacheService: CacheService? = nil,
        progressRefreshState: ProgressRefreshState? = nil
    ) {
        print("HomeViewModel init")
        self.coordinator = coordinator
        self.dailySummaryService = dailySummaryService
        self.foodService = foodService
        self.todayFoodVM = todayFoodVM
        self.waterVM = waterVM
        self.goalsVM = goalsVM
        self.activityVM = activityVM
        self.workoutVM = workoutVM
        self.sleepVM = sleepVM
        self.activitySync = activitySync
        self.progressRefreshState = progressRefreshState
        
        self.cacheService = cacheService

        activitySync.onActivityUpdate = { [weak activityVM] activity in
            Task { @MainActor in
                activityVM?.setActivity(activity)
            }
        }
    }

    deinit { print("HomeViewModel deinit") }

    func onAppear() async {
        await activityVM.checkPermission()
        await sleepVM.checkPermission()
        await workoutVM.loadLatest()
        await workoutVM.checkWorkoutAchievements()
    }

    func handleBecameActive() async {
        let now = Date()

        if let last = lastForegroundRefreshAt,
           now.timeIntervalSince(last) < Self.foregroundDedupeWindow {
            return
        }

        lastForegroundRefreshAt = now

        await onAppear()

        if !activityVM.needsHealthConnect {
            await activitySync.refresh()
        }
    }

    func connectHealth() async {
        await activityVM.connectTapped()

        if !activityVM.needsHealthConnect {
            activitySync.authorizationDidChange()
        }

        await sleepVM.connectTapped()
    }

    func refreshAll() async {
        await cacheService?.remove("food_today")
        await cacheService?.remove("water_today")
        await cacheService?.remove("summary_today")
        await cacheService?.removeByPrefix("chart_summaries")
        

        await withDiscardingTaskGroup { [self] group in
            group.addTask { await self.loadDashboardSummary(forceRefresh: true) }
            group.addTask { await self.goalsVM.loadGoals() }
            group.addTask { await self.goalsVM.loadPersonalization() }
            group.addTask { await self.todayFoodVM.loadToday(forceNetwork: true) }
            group.addTask { await self.waterVM.loadToday(forceRefresh: true) }
            
        }
    }

    func loadAll() async {
        await withDiscardingTaskGroup { [self] group in
            group.addTask { await self.loadDashboardSummary() }
            group.addTask { await self.goalsVM.loadGoals() }
            group.addTask { await self.goalsVM.loadPersonalization() }
            group.addTask { await self.todayFoodVM.loadToday() }
            group.addTask { await self.waterVM.loadToday() }
        }
        lastGoalsRevision = progressRefreshState?.revision
    }

    func refreshGoalsIfNeeded() async {
        guard let revision = progressRefreshState?.revision else { return }
        guard lastGoalsRevision != revision else { return }

        await withDiscardingTaskGroup { [self] group in
            group.addTask { await self.loadDashboardSummary() }
            group.addTask { await self.goalsVM.loadGoals() }
            group.addTask { await self.goalsVM.loadPersonalization() }
        }
        lastGoalsRevision = revision
    }

    func loadDashboardSummary(forceRefresh: Bool = false) async {
        if !forceRefresh, let dashboardSummaryTask {
            await dashboardSummaryTask.value
            return
        }

        if forceRefresh {
            await cacheService?.remove("summary_today")
        }

        dashboardSummaryGeneration &+= 1
        let generation = dashboardSummaryGeneration
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performLoadDashboardSummary(generation: generation)
        }
        dashboardSummaryTask = task
        await task.value
        if generation == dashboardSummaryGeneration {
            dashboardSummaryTask = nil
        }
    }

    private func performLoadDashboardSummary(generation: Int) async {
        if let cached: DailySummary = try? await cacheService?.get(
            "summary_today",
            retainExpired: true
        ) {
            print("[HomeVM] loadDashboardSummary → cache HIT")
            applyDashboardSummary(cached, generation: generation)
            return
        }

        if isCurrentDashboardSummaryGeneration(generation),
           case .loaded = dailySummaryState {
        } else if isCurrentDashboardSummaryGeneration(generation) {
            dailySummaryState = .loading
        }
        do {
            print("[Network] HomeVM loadDashboardSummary")
            let result = try await dailySummaryService.getTodayDailySummary()
            guard isCurrentDashboardSummaryGeneration(generation) else { return }
            try? await cacheService?.set("summary_today", result, ttl: 300)
            print("[HomeVM] loadDashboardSummary → network OK")
            applyDashboardSummary(result, generation: generation)
        } catch let error as APIError {
            guard isCurrentDashboardSummaryGeneration(generation) else { return }
            if case .unauthorized = error {
                coordinator?.goToAuth()
            }
            if let cached: DailySummary = try? await cacheService?.get("summary_today", ignoreTTL: true) {
                print("[HomeVM] loadDashboardSummary → fallback to stale cache")
                applyDashboardSummary(cached, generation: generation)
            } else {
                print("[HomeVM] loadDashboardSummary → FAIL, no cache | API \(error)")
                let appError: AppError = ErrorMapper.map(error)
                dailySummaryState = .error(appError)
            }
        } catch {
            guard isCurrentDashboardSummaryGeneration(generation) else { return }
            if let cached: DailySummary = try? await cacheService?.get("summary_today", ignoreTTL: true) {
                print("[HomeVM] loadDashboardSummary → fallback to stale cache")
                applyDashboardSummary(cached, generation: generation)
            } else {
                print("[HomeVM] loadDashboardSummary → FAIL, no cache | \(error)")
                let appError: AppError = ErrorMapper.map(error)
                dailySummaryState = .error(appError)
            }
        }
    }

    private func isCurrentDashboardSummaryGeneration(_ generation: Int) -> Bool {
        generation == dashboardSummaryGeneration
    }

    private func applyDashboardSummary(_ summary: DailySummary, generation: Int) {
        guard isCurrentDashboardSummaryGeneration(generation) else { return }
        dailySummaryState = summary.id == nil ? .empty : .loaded(summary)
    }

    func deleteFood(id: String) async {
        let success = await todayFoodVM.deleteFood(id: id)
        guard success else { return }
        await loadDashboardSummary(forceRefresh: true)
    }

    func addWater() async {
        let success = await waterVM.createWater()
        guard success else { return }
        await loadDashboardSummary(forceRefresh: true)
    }

    func deleteWater(id: String) async {
        let success = await waterVM.deleteWater(id: id)
        guard success else { return }
        await loadDashboardSummary(forceRefresh: true)
    }
}
