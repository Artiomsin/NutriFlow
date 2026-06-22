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

    init(
        coordinator: AppCoordinator,
        dailySummaryService: DailySummaryServiceProtocol,
        foodViewModel: FoodViewModel,
        waterViewModel: WaterViewModel,
        goalsViewModel: GoalsViewModel
    ) {
        print("HomeViewModel init")
        self.coordinator = coordinator
        self.dailySummaryService = dailySummaryService
        self.foodViewModel = foodViewModel
        self.waterViewModel = waterViewModel
        self.goalsViewModel = goalsViewModel
    }

    deinit { print("HomeViewModel deinit") }

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
        dailySummaryState = .loading
        dashboardFoodEntries = []
        dashboardWaterEntries = []
        do {
            let dashboard = try await dailySummaryService.getDashboardToday()
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
            dailySummaryState = .error(error)
        } catch {
            dailySummaryState = .error(error)
        }
    }

    func loadToday() async {
        dailySummaryState = .loading
        do {
            let result = try await dailySummaryService.getTodayDailySummary()
            if result.id == nil {
                dailySummaryState = .empty
            } else {
                dailySummaryState = .loaded(result)
            }
        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator?.goToAuth()
            }
            dailySummaryState = .error(error)
        } catch {
            dailySummaryState = .error(error)
        }
    }
}
