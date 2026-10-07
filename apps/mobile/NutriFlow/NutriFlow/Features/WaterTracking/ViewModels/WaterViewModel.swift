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
    
    func loadToday() async {
        if let cached: [WaterEntry] = try? await cacheService?.get("water_today") {
            state = .loaded(cached)
            return
        }

        if case .loaded = state {} else { state = .loading }
        do {
            #if DEBUG
            print("[Network] WaterVM loadToday")
            #endif
            let entries = try await service.getTodayWater()
            try? await cacheService?.set("water_today", entries, ttl: 300)
            state = .loaded(entries)
        } catch {
            if let cached: [WaterEntry] = try? await cacheService?.get("water_today", ignoreTTL: true) {
                state = .loaded(cached)
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

    /// Refetches the day after a successful write. A failing refetch must never leave
    /// the state stuck in .saving, so it falls back to loadToday(), which owns the
    /// stale-cache path and the error mapping.
    private func refreshAfterWrite() async {
        do {
            let entries = try await service.getTodayWater()
            try? await cacheService?.set("water_today", entries, ttl: 300)
            state = .loaded(entries)
        } catch {
            await loadToday()
        }
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
