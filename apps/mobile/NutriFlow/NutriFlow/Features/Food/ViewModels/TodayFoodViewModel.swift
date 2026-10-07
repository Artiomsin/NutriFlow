import Foundation
import Observation
import UIKit

enum TodayFoodState {
    case idle
    case loading
    case loaded([FoodEntry])
    case error(AppError)
}

@Observable
@MainActor
final class TodayFoodViewModel {
    var state: TodayFoodState = .idle
    var bannerError: AppError?

    @ObservationIgnored private let service: FoodServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let cacheService: CacheService?
    @ObservationIgnored private let progressRefreshState: ProgressRefreshState?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var pendingDeleteId: String?
    @ObservationIgnored private let goalsService: GoalsServiceProtocol?
    @ObservationIgnored private let goalsProvider: (() -> UserGoals?)?
    @ObservationIgnored private let achievementService: AchievementService?
    @ObservationIgnored private let achievementNotificationService: AchievementNotificationService?

    init(
        service: FoodServiceProtocol,
        coordinator: AppCoordinator?,
        cacheService: CacheService? = nil,
        progressRefreshState: ProgressRefreshState? = nil,
        goalsService: GoalsServiceProtocol? = nil,
        goalsProvider: (() -> UserGoals?)? = nil,
        achievementService: AchievementService? = nil,
        achievementNotificationService: AchievementNotificationService? = nil
    ) {
        print("TodayFoodViewModel init")
        self.service = service
        self.coordinator = coordinator
        self.cacheService = cacheService
        self.progressRefreshState = progressRefreshState
        self.goalsService = goalsService
        self.goalsProvider = goalsProvider
        self.achievementService = achievementService
        self.achievementNotificationService = achievementNotificationService
    }

    deinit { print("TodayFoodViewModel deinit") }

    func loadToday(forceNetwork: Bool = false) async {
        loadTask?.cancel()
        let task = Task { await performLoad(forceNetwork: forceNetwork) }
        loadTask = task
        await task.value
    }

    private func performLoad(forceNetwork: Bool) async {
        if !forceNetwork, let cached: [FoodEntry] = try? await cacheService?.get("food_today") {
            if bailIfCancelled() { return }
            print("[TodayFoodVM] loadToday → cache HIT (\(cached.count) entries)")
            state = .loaded(cached)
            return
        }

        if bailIfCancelled() { return }

        if case .loaded = state {} else { state = .loading }
        do {
            print("[Network] TodayFoodVM loadToday")
            let food = try await service.getTodayFood()
            if bailIfCancelled() { return }
            try? await cacheService?.set("food_today", food, ttl: 300)
            print("[TodayFoodVM] loadToday → network OK (\(food.count) entries)")
            state = .loaded(food)
        } catch {
            if bailIfCancelled() { return }
            let appError = ErrorMapper.map(error)
            routeAuth(appError)
            guard appError != .cancelled else { return }
            // A failed load now owns the banner, so any pending delete intent is
            // superseded: retryBanner must retry this load, not the older delete.
            pendingDeleteId = nil
            if case .loaded = state {
                print("[TodayFoodVM] loadToday → FAIL, keeping in-memory data | \(error)")
                bannerError = appError
            } else if let cached: [FoodEntry] = try? await cacheService?.get("food_today", ignoreTTL: true) {
                if bailIfCancelled() { return }
                print("[TodayFoodVM] loadToday → fallback to stale cache (\(cached.count) entries)")
                state = .loaded(cached)
                bannerError = appError
            } else {
                print("[TodayFoodVM] loadToday → FAIL, nothing to show | \(error)")
                state = .error(appError)
            }
        }
    }

    private func bailIfCancelled() -> Bool {
        guard Task.isCancelled else { return false }
        if case .loading = state { state = .idle }
        return true
    }

    func reloadAfterMutation() async {
        await cacheService?.remove("food_today")
        await cacheService?.remove("summary_today")
        await cacheService?.removeByPrefix("chart_summaries")
        await cacheService?.removeByPrefix("analytics_")
        await loadToday(forceNetwork: true)
        await checkNutritionAchievements()
    }

    func notifyDataMutated() {
        progressRefreshState?.invalidate()
    }

    func retry() {
        Task { await loadToday(forceNetwork: true) }
    }

    @discardableResult
    func deleteFood(id: String) async -> Bool {
        pendingDeleteId = id
        bannerError = nil
        do {
            print("[Network] TodayFoodVM deleteFood")
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "yyyy-MM-dd"
            try await service.deleteFoodEntry(id: id, date: df.string(from: Date()))
            removeLocally(id: id)
            await reloadAfterMutation()
            notifyDataMutated()
            pendingDeleteId = nil
            return true
        } catch {
            // A retry after a lost response hits an already-deleted entry. The
            // caller's intent is satisfied, so treat it as success instead of
            // reporting a failure for an operation that already took effect.
            if ErrorMapper.map(error) == .notFound {
                removeLocally(id: id)
                pendingDeleteId = nil
                await reloadAfterMutation()
                notifyDataMutated()
                return true
            }
            presentBanner(error)
            return false
        }
    }

    private func removeLocally(id: String) {
        if case .loaded(let entries) = state {
            state = .loaded(entries.filter { $0.id != id })
        }
    }

    func retryBanner() {
        if let id = pendingDeleteId {
            Task { _ = await deleteFood(id: id) }
        } else {
            bannerError = nil
            Task { await loadToday(forceNetwork: true) }
        }
    }

    func setPreviewState(_ newState: TodayFoodState) {
        state = newState
    }

    private func routeAuth(_ appError: AppError) {
        if appError == .unauthorized {
            coordinator?.goToAuth()
        }
    }

    private func presentBanner(_ error: Error) {
        let appError = ErrorMapper.map(error)
        routeAuth(appError)
        guard appError != .cancelled else { return }
        bannerError = appError
    }

    private func checkNutritionAchievements() async {
        guard
            let achievementService,
            let achievementNotificationService,
            let goals = await loadGoalsForAchievements(),
            let calorieGoal = goals.dailyCaloriesGoal,
            calorieGoal > 0
        else { return }

        let entries: [FoodEntry]
        if case .loaded(let loaded) = state {
            entries = loaded
        } else {
            entries = (try? await service.getTodayFood()) ?? []
        }

        let consumed = entries.reduce(0) { $0 + $1.calories }
        let items = achievementService.checkCalories(consumed: consumed, goal: calorieGoal)
        #if DEBUG
        print("[AchievementNotification] calories total=\(consumed) goal=\(calorieGoal)")
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
}
