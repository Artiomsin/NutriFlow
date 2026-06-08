import SwiftUI

enum HomeFactory {
    @MainActor @ViewBuilder
    static func make(container: AppDependency, coordinator: AppCoordinator) -> some View {
        let foodVM = FoodViewModel(
            service: container.foodService
        )
        let waterVM = WaterViewModel(
            service: container.waterTrackingService
        )
        let dailyVM = DailySummaryViewModel(
            coordinator: coordinator,
            service: container.dailySummaryService,
            foodService: container.foodService,
            waterService: container.waterTrackingService
        )
        let goalsVM = GoalsViewModel(service: container.goalsService)
        
        let homeVM = HomeViewModel(
            coordinator: coordinator,
            foodViewModel: foodVM,
            waterViewModel: waterVM,
            dailyViewModel: dailyVM,
            goalsViewModel: goalsVM
        )
        HomeView(homeViewModel: homeVM)
    }
}
