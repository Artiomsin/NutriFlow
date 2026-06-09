import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {

    let foodViewModel: FoodViewModel
    let waterViewModel: WaterViewModel
    let dailyViewModel: DailySummaryViewModel
    let goalsViewModel: GoalsViewModel

    var userGoals: UserGoals? {
        if case .loaded(let goals) = goalsViewModel.state { return goals }
        return nil
    }
    
    @ObservationIgnored private let coordinator: AppCoordinator

    init(
        coordinator: AppCoordinator,
        foodViewModel: FoodViewModel,
        waterViewModel: WaterViewModel,
        dailyViewModel: DailySummaryViewModel,
        goalsViewModel: GoalsViewModel
        
    ) {
        self.coordinator = coordinator
        self.foodViewModel = foodViewModel
        self.waterViewModel = waterViewModel
        self.dailyViewModel = dailyViewModel
        self.goalsViewModel = goalsViewModel
    }

    func loadAll() async {
        await withDiscardingTaskGroup { [self] group in
            group.addTask { await self.dailyViewModel.loadDashboardToday() }
            group.addTask { await self.goalsViewModel.loadGoals() }
        }

        switch dailyViewModel.state {
        case .loaded:
            foodViewModel.state = .loaded(dailyViewModel.dashboardFoodEntries)
            waterViewModel.state = .loaded(dailyViewModel.dashboardWaterEntries)
        case .empty, .error:
            foodViewModel.state = .loaded([])
            waterViewModel.state = .loaded([])
        case .idle, .loading:
            foodViewModel.state = .loaded([])
            waterViewModel.state = .loaded([])
        }
        checkAuth()
    }

    func reloadGoals() async {
        await goalsViewModel.loadGoals()
    }

    func addFood() async {
        await foodViewModel.createFood()
        guard !checkAuth() else { return }
        await dailyViewModel.loadToday()
    }
    
    func deleteFood(id: String) async {
        await foodViewModel.deleteFood(id: id)
        guard !checkAuth() else { return }
        await dailyViewModel.loadToday()
    }

    func addWater() async {
        await waterViewModel.createWater()
        guard !checkAuth() else { return }
        await dailyViewModel.loadToday()
    }
    
    func deleteWater(id: String) async {
        await waterViewModel.deleteWater(id: id)
        guard !checkAuth() else { return }
        await dailyViewModel.loadToday()
    }
    
    @discardableResult
    private func checkAuth() -> Bool {
        if case .error(let error) = foodViewModel.state,
           (error as? APIError) == .unauthorized {
            coordinator.goToAuth()
            return true
        }
        if case .error(let error) = waterViewModel.state,
           (error as? APIError) == .unauthorized {
            coordinator.goToAuth()
            return true
        }
        return false
    }
}
