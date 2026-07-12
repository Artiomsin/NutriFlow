import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {

    let todayFoodVM: TodayFoodViewModel
    let waterVM: WaterViewModel
    let goalsVM: GoalsViewModel

    var dailySummaryState: DailySummaryState = .idle

    var userGoals: UserGoals? {
        if case .loaded(let goals) = goalsVM.state { return goals }
        return nil
    }

    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let dailySummaryService: DailySummaryServiceProtocol
    @ObservationIgnored let foodService: FoodServiceProtocol
    @ObservationIgnored private let guestStore: GuestStore?
    @ObservationIgnored private let cacheService: CacheService?
    @ObservationIgnored private var isGoingToAuthFromSheet = false

    var showExpiredWarning = false

    init(
        coordinator: AppCoordinator,
        dailySummaryService: DailySummaryServiceProtocol,
        foodService: FoodServiceProtocol,
        todayFoodVM: TodayFoodViewModel,
        waterVM: WaterViewModel,
        goalsVM: GoalsViewModel,
        guestStore: GuestStore? = nil,
        cacheService: CacheService? = nil
    ) {
        print("HomeViewModel init")
        self.coordinator = coordinator
        self.dailySummaryService = dailySummaryService
        self.foodService = foodService
        self.todayFoodVM = todayFoodVM
        self.waterVM = waterVM
        self.goalsVM = goalsVM
        self.guestStore = guestStore
        self.cacheService = cacheService
    }

    deinit { print("HomeViewModel deinit") }

    func goToAuth() {
        coordinator?.goToAuth()
    }

    func goToAuthFromSheet() {
        isGoingToAuthFromSheet = true
        coordinator?.goToAuth()
    }

    func checkExpiredDay() {
        guard let store = guestStore, store.isExpired, !store.didShowExpiredWarning else { return }
        store.didShowExpiredWarning = true
        showExpiredWarning = true
    }

    func dismissExpiredDay() async {
        guestStore?.initializeNewDay()
        await cacheService?.remove("dashboard_today")
        await cacheService?.remove("summary_today")
        await cacheService?.remove("chart_today")
        await cacheService?.remove("food_today")
        await cacheService?.remove("water_today")
        await cacheService?.removeByPrefix("chart_summaries")
        await cacheService?.removeByPrefix("analytics_")
        showExpiredWarning = false
    }

    func handleSheetDismiss() async {
        guard !isGoingToAuthFromSheet else {
            isGoingToAuthFromSheet = false
            return
        }
        await dismissExpiredDay()
    }

    func refreshAll() async {
        await cacheService?.remove("food_today")
        await cacheService?.remove("water_today")
        await cacheService?.remove("dashboard_today")
        await cacheService?.remove("summary_today")
        await cacheService?.remove("chart_today")
        await cacheService?.removeByPrefix("chart_summaries")
        await cacheService?.removeByPrefix("analytics_")
        await loadAll()
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
        await todayFoodVM.deleteFood(id: id)
        await loadDashboardSummary()
    }

    func addWater() async {
        await waterVM.createWater()
        await loadDashboardSummary()
    }

    func deleteWater(id: String) async {
        await waterVM.deleteWater(id: id)
        await loadDashboardSummary()
    }

    func reloadGoals() async {
        await goalsVM.loadGoals()
    }
}
