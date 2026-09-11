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
        
        cacheService: CacheService? = nil
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
        await cacheService?.remove("dashboard_today")
        await cacheService?.remove("summary_today")
        await cacheService?.remove("chart_today")
        await cacheService?.removeByPrefix("chart_summaries")
        

        await withDiscardingTaskGroup { [self] group in
            group.addTask { await self.loadDashboardSummary() }
            group.addTask { await self.goalsVM.loadGoals() }
            group.addTask { await self.todayFoodVM.loadToday() }
            group.addTask { await self.waterVM.loadToday() }
            
        }
    }

    func loadAll() async {
        await withDiscardingTaskGroup { [self] group in
            group.addTask { await self.loadDashboardSummary() }
            group.addTask { await self.goalsVM.loadGoals() }
        }
    }

    func loadDashboardSummary() async {
        if let cached: DailySummary = try? await cacheService?.get("summary_today") {
            print("[HomeVM] loadDashboardSummary → cache HIT")
            dailySummaryState = cached.id == nil ? .empty : .loaded(cached)
            return
        }

        if case .loaded = dailySummaryState {} else { dailySummaryState = .loading }
        do {
            print("[Network] HomeVM loadDashboardSummary")
            let result = try await dailySummaryService.getTodayDailySummary()
            try? await cacheService?.set("summary_today", result, ttl: 300)
            print("[HomeVM] loadDashboardSummary → network OK")
            dailySummaryState = result.id == nil ? .empty : .loaded(result)
        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator?.goToAuth()
            }
            if let cached: DailySummary = try? await cacheService?.get("summary_today", ignoreTTL: true) {
                print("[HomeVM] loadDashboardSummary → fallback to stale cache")
                dailySummaryState = cached.id == nil ? .empty : .loaded(cached)
            } else {
                print("[HomeVM] loadDashboardSummary → FAIL, no cache")
                dailySummaryState = .error(error)
            }
        } catch {
            if let cached: DailySummary = try? await cacheService?.get("summary_today", ignoreTTL: true) {
                print("[HomeVM] loadDashboardSummary → fallback to stale cache")
                dailySummaryState = cached.id == nil ? .empty : .loaded(cached)
            } else {
                print("[HomeVM] loadDashboardSummary → FAIL, no cache")
                dailySummaryState = .error(error)
            }
        }
    }

    func deleteFood(id: String) async {
        let success = await todayFoodVM.deleteFood(id: id)
        guard success else { return }
        await loadDashboardSummary()
    }

    func addWater() async {
        let success = await waterVM.createWater()
        guard success else { return }
        await loadDashboardSummary()
    }

    func deleteWater(id: String) async {
        let success = await waterVM.deleteWater(id: id)
        guard success else { return }
        await loadDashboardSummary()
    }
}
