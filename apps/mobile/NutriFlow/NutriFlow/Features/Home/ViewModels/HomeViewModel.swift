import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {

    let foodViewModel: FoodViewModel
    let waterViewModel: WaterViewModel
    let goalsViewModel: GoalsViewModel

    var dailySummaryState: DailySummaryState = .idle
    var dashboardFoodEntries: [FoodEntry] = []
    var dashboardWaterEntries: [WaterEntry] = []

    var userGoals: UserGoals? {
        if case .loaded(let goals) = goalsViewModel.state { return goals }
        return nil
    }

    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let dailySummaryService: DailySummaryServiceProtocol
    @ObservationIgnored private let guestStore: GuestStore?
    @ObservationIgnored private let cacheService: CacheService?
    @ObservationIgnored private var isGoingToAuthFromSheet = false

    var showExpiredWarning = false

    init(
        coordinator: AppCoordinator,
        dailySummaryService: DailySummaryServiceProtocol,
        foodViewModel: FoodViewModel,
        waterViewModel: WaterViewModel,
        goalsViewModel: GoalsViewModel,
        guestStore: GuestStore? = nil,
        cacheService: CacheService? = nil
    ) {
        print("HomeViewModel init")
        self.coordinator = coordinator
        self.dailySummaryService = dailySummaryService
        self.foodViewModel = foodViewModel
        self.waterViewModel = waterViewModel
        self.goalsViewModel = goalsViewModel
        self.guestStore = guestStore
        self.cacheService = cacheService
    }

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

    deinit { print("HomeViewModel deinit") }

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
            group.addTask { await self.loadDashboardToday() }
            group.addTask { await self.goalsViewModel.loadGoals() }
        }

        switch dailySummaryState {
        case .loaded:
            foodViewModel.state = .loaded(dashboardFoodEntries)
            waterViewModel.state = .loaded(dashboardWaterEntries)
        case .empty, .error:
            foodViewModel.state = .loaded([])
            waterViewModel.state = .loaded([])
        case .idle, .loading:
            foodViewModel.state = .loaded([])
            waterViewModel.state = .loaded([])
        }
    }

    func reloadGoals() async {
        await goalsViewModel.loadGoals()
    }

    func addFood() async {
        await foodViewModel.createFood()
        await loadToday()
    }

    func deleteFood(id: String) async {
        await foodViewModel.deleteFood(id: id)
        await loadToday()
    }

    func addWater() async {
        await waterViewModel.createWater()
        await loadToday()
    }

    func deleteWater(id: String) async {
        await waterViewModel.deleteWater(id: id)
        await loadToday()
    }

    func loadDashboardToday() async {
        if let cached: DashboardTodayResponse = try? await cacheService?.get("dashboard_today") {
            #if DEBUG
            print("[HomeVM] loadDashboard → cache HIT")
            #endif
            dailySummaryState = cached.dailySummary.id == nil ? .empty : .loaded(cached.dailySummary)
            dashboardFoodEntries = cached.foodEntries
            dashboardWaterEntries = cached.waterEntries
            return
        }

        if case .loaded = dailySummaryState {} else { dailySummaryState = .loading }
        dashboardFoodEntries = []
        dashboardWaterEntries = []
        do {
            #if DEBUG
            print("[Network] HomeVM loadDashboardToday")
            #endif
            let dashboard = try await dailySummaryService.getDashboardToday()
            try? await cacheService?.set("dashboard_today", dashboard, ttl: 300)
            #if DEBUG
            print("[HomeVM] loadDashboard → network OK")
            #endif
            if dashboard.dailySummary.id == nil {
                dailySummaryState = .empty
            } else {
                dailySummaryState = .loaded(dashboard.dailySummary)
            }
            dashboardFoodEntries = dashboard.foodEntries
            dashboardWaterEntries = dashboard.waterEntries
        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator?.goToAuth()
            }
            if let cached: DashboardTodayResponse = try? await cacheService?.get("dashboard_today", ignoreTTL: true) {
                #if DEBUG
                print("[HomeVM] loadDashboard → fallback to stale cache")
                #endif
                dailySummaryState = cached.dailySummary.id == nil ? .empty : .loaded(cached.dailySummary)
                dashboardFoodEntries = cached.foodEntries
                dashboardWaterEntries = cached.waterEntries
            } else {
                #if DEBUG
                print("[HomeVM] loadDashboard → FAIL, no cache")
                #endif
                dailySummaryState = .error(error)
            }
        } catch {
            if let cached: DashboardTodayResponse = try? await cacheService?.get("dashboard_today", ignoreTTL: true) {
                #if DEBUG
                print("[HomeVM] loadDashboard → fallback to stale cache")
                #endif
                dailySummaryState = cached.dailySummary.id == nil ? .empty : .loaded(cached.dailySummary)
                dashboardFoodEntries = cached.foodEntries
                dashboardWaterEntries = cached.waterEntries
            } else {
                #if DEBUG
                print("[HomeVM] loadDashboard → FAIL, no cache")
                #endif
                dailySummaryState = .error(error)
            }
        }
    }

    func loadToday() async {
        if let cached: DailySummary = try? await cacheService?.get("summary_today") {
            #if DEBUG
            print("[HomeVM] loadToday → cache HIT")
            #endif
            dailySummaryState = cached.id == nil ? .empty : .loaded(cached)
            return
        }

        if case .loaded = dailySummaryState {} else { dailySummaryState = .loading }
        do {
            #if DEBUG
            print("[Network] HomeVM loadToday")
            #endif
            let result = try await dailySummaryService.getTodayDailySummary()
            try? await cacheService?.set("summary_today", result, ttl: 300)
            #if DEBUG
            print("[HomeVM] loadToday → network OK")
            #endif
            if result.id == nil {
                dailySummaryState = .empty
            } else {
                dailySummaryState = .loaded(result)
            }
        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator?.goToAuth()
            }
            if let cached: DailySummary = try? await cacheService?.get("summary_today", ignoreTTL: true) {
                #if DEBUG
                print("[HomeVM] loadToday → fallback to stale cache")
                #endif
                dailySummaryState = cached.id == nil ? .empty : .loaded(cached)
            } else {
                #if DEBUG
                print("[HomeVM] loadToday → FAIL, no cache")
                #endif
                dailySummaryState = .error(error)
            }
        } catch {
            if let cached: DailySummary = try? await cacheService?.get("summary_today", ignoreTTL: true) {
                #if DEBUG
                print("[HomeVM] loadToday → fallback to stale cache")
                #endif
                dailySummaryState = cached.id == nil ? .empty : .loaded(cached)
            } else {
                #if DEBUG
                print("[HomeVM] loadToday → FAIL, no cache")
                #endif
                dailySummaryState = .error(error)
            }
        }
    }
}
