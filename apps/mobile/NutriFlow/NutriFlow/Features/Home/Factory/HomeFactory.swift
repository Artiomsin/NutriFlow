import SwiftUI

enum HomeFactory {
    @MainActor @ViewBuilder
    static func make(
        coordinator: AppCoordinator,
        foodService: FoodServiceProtocol,
        waterService: WaterTrackingServiceProtocol,
        goalsService: GoalsServiceProtocol,
        dailySummaryService: DailySummaryServiceProtocol
    ) -> some View {
        let foodVM = FoodViewModel(coordinator: coordinator, service: foodService)
        let waterVM = WaterViewModel(coordinator: coordinator, service: waterService)
        let goalsVM = GoalsViewModel(coordinator: coordinator, service: goalsService)

        let homeVM = HomeViewModel(
            coordinator: coordinator,
            dailySummaryService: dailySummaryService,
            foodViewModel: foodVM,
            waterViewModel: waterVM,
            goalsViewModel: goalsVM
        )
        HomeView(homeViewModel: homeVM)
    }
}
