import Foundation
import Observation

@Observable
@MainActor
final class WaterViewModel {

    var state: WaterState = .idle
    var amountMl: String = ""
    var addError: AppError?
    
    @ObservationIgnored private let service: WaterTrackingServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let cacheService: CacheService?
    @ObservationIgnored private let progressRefreshState: ProgressRefreshState?
    @ObservationIgnored private let analyticsTracker: AnalyticsTracking?
    @ObservationIgnored private let goalsService: GoalsServiceProtocol?
    @ObservationIgnored private let goalsProvider: (() -> UserGoals?)?
    @ObservationIgnored private let achievementService: AchievementService?
    @ObservationIgnored private let achievementNotificationService: AchievementNotificationService?
    @ObservationIgnored private var waterLoadTask: Task<Void, Never>?
    @ObservationIgnored private var waterLoadGeneration = 0

    init(
        coordinator: AppCoordinator,
        service: WaterTrackingServiceProtocol,
        cacheService: CacheService? = nil,
        progressRefreshState: ProgressRefreshState? = nil,
        analyticsTracker: AnalyticsTracking? = nil,
        goalsService: GoalsServiceProtocol? = nil,
        goalsProvider: (() -> UserGoals?)? = nil,
        achievementService: AchievementService? = nil,
        achievementNotificationService: AchievementNotificationService? = nil
    ) {
        #if DEBUG
        print("WaterViewModel init")
        #endif
        self.coordinator = coordinator
        self.service = service
        self.cacheService = cacheService
        self.progressRefreshState = progressRefreshState
        self.analyticsTracker = analyticsTracker
        self.goalsService = goalsService
        self.goalsProvider = goalsProvider
        self.achievementService = achievementService
        self.achievementNotificationService = achievementNotificationService
    }

    #if DEBUG
    deinit { print("WaterViewModel deinit") }
    #endif

    func trackScreenView() {
        analyticsTracker?.track(.screenView(screen: "add_water"))
    }
    
    func loadToday(
        forceRefresh: Bool = false,
        keepsSavingState: Bool = false
    ) async {
        if !forceRefresh, let waterLoadTask {
            await waterLoadTask.value
            return
        }

        if forceRefresh {
            await cacheService?.remove("water_today")
        }

        waterLoadGeneration &+= 1
        let generation = waterLoadGeneration
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performLoadToday(
                generation: generation,
                keepsSavingState: keepsSavingState
            )
        }
        waterLoadTask = task
        await task.value
        if generation == waterLoadGeneration {
            waterLoadTask = nil
        }
    }

    private func performLoadToday(
        generation: Int,
        keepsSavingState: Bool
    ) async {
        if let cached: [WaterEntry] = try? await cacheService?.get(
            "water_today",
            retainExpired: true
        ) {
            applyWaterEntries(cached, generation: generation)
            return
        }

        if isCurrentWaterLoad(generation), !keepsSavingState,
           case .loaded = state {
        } else if isCurrentWaterLoad(generation), !keepsSavingState {
            state = .loading
        }
        do {
            #if DEBUG
            print("[Network] WaterVM loadToday")
            #endif
            let entries = try await service.getTodayWater()
            guard isCurrentWaterLoad(generation) else { return }
            try? await cacheService?.set("water_today", entries, ttl: 300)
            applyWaterEntries(entries, generation: generation)
        } catch {
            guard isCurrentWaterLoad(generation) else { return }
            if let cached: [WaterEntry] = try? await cacheService?.get("water_today", ignoreTTL: true) {
                applyWaterEntries(cached, generation: generation)
            } else if case .loaded = state {
                #if DEBUG
                print("[WaterVM] loadToday → FAIL, keeping existing data | \(error)")
                #endif
            } else {
                #if DEBUG
                print("[WaterVM] loadToday → FAIL, no cache | \(error)")
                #endif
                handle(error)
            }
        }
    }

    @discardableResult
    func createWater() async -> Bool {
        guard let ml = Int(amountMl), ml > 0 else {
            addError = .validation(message: "Quantity must be greater than zero.")
            return false
        }

        return await createWater(amountMl: ml, clearsForm: true)
    }

    /// Saves water recognized by the scanner without changing the add-water form.
    @discardableResult
    func createWater(amountMl: Int) async -> Bool {
        guard amountMl > 0 else {
            return false
        }

        return await createWater(amountMl: amountMl, clearsForm: false)
    }

    private func createWater(amountMl: Int, clearsForm: Bool) async -> Bool {

        addError = nil
        let stateBeforeWrite = state
        invalidateWaterLoad()
        state = .saving

        do {
            #if DEBUG
            print("[Network] WaterVM createWater")
            #endif
            try await service.createWaterEntry(amountMl: amountMl, date: nil)
            await cacheService?.remove("water_today")
            await cacheService?.remove("summary_today")
            await cacheService?.removeByPrefix("chart_summaries")
            await cacheService?.removeByPrefix("analytics_")
            progressRefreshState?.invalidate()

            await refreshAfterWrite()
            await checkWaterAchievements()
            if clearsForm {
                clearForm()
            }
            return true
        } catch {
            let mapped = ErrorMapper.map(error)
            routeAuth(mapped)
            // The write failed but the list behind the sheet is still valid, so the
            // failure is reported in addError only. Restoring the pre-write state
            // leaves .saving and never blanks WaterSection.
            state = stateBeforeWrite
            addError = mapped == .cancelled ? nil : mapped
            return false
        }
    }

    @discardableResult
    func deleteWater(id: String) async -> Bool {
        do {
            invalidateWaterLoad()
            #if DEBUG
            print("[Network] WaterVM deleteWater")
            #endif
            try await service.deleteWaterEntry(id: id, date: nil)
            await cacheService?.remove("water_today")
            await cacheService?.remove("summary_today")
            await cacheService?.removeByPrefix("chart_summaries")
            await cacheService?.removeByPrefix("analytics_")
            progressRefreshState?.invalidate()

            await refreshAfterWrite()
            return true
        } catch {
            handle(error)
            return false
        }
    }

    /// Refetches the day after a successful write without allowing a pre-write
    /// request to overwrite the newly saved list.
    private func refreshAfterWrite() async {
        await loadToday(forceRefresh: true, keepsSavingState: true)
    }

    private func invalidateWaterLoad() {
        waterLoadGeneration &+= 1
        waterLoadTask = nil
    }

    private func isCurrentWaterLoad(_ generation: Int) -> Bool {
        generation == waterLoadGeneration
    }

    private func applyWaterEntries(_ entries: [WaterEntry], generation: Int) {
        guard isCurrentWaterLoad(generation) else { return }
        state = .loaded(entries)
    }

    private func checkWaterAchievements() async {
        guard
            let achievementService,
            let achievementNotificationService,
            let goals = await loadGoalsForAchievements(),
            let goalMl = goals.dailyWaterGoal,
            goalMl > 0
        else { return }

        let entries: [WaterEntry]
        if case .loaded(let loaded) = state {
            entries = loaded
        } else {
            entries = (try? await service.getTodayWater()) ?? []
        }

        let totalMl = entries.reduce(0) { $0 + $1.amountMl }
        let items = achievementService.checkWater(totalMl: totalMl, goalMl: goalMl)
        #if DEBUG
        print("[AchievementNotification] water total=\(totalMl) goal=\(goalMl)")
        #endif
        guard !items.isEmpty else { return }
        await achievementNotificationService.notifyIfNeeded(achievements: items)
    }

    private func loadGoalsForAchievements() async -> UserGoals? {
        if let goals = goalsProvider?() {
            return goals
        }
        return try? await goalsService?.getGoals()
    }

    private func clearForm() {
        amountMl = ""
    }
    
    func setPreviewState(_ newState: WaterState) {
        state = newState
    }
    
    private func routeAuth(_ appError: AppError) {
        if appError == .unauthorized {
            coordinator?.goToAuth()
        }
    }

    private func handle(_ error: Error) {
        let appError = ErrorMapper.map(error)

        if appError == .cancelled {
            state = .idle
            return
        }

        routeAuth(appError)

        if appError == .unauthorized {
            state = .idle
            return
        }

        state = .error(appError)
    }
}
