import SwiftUI

enum HomeFactory {
    @MainActor @ViewBuilder
    static func make(
        coordinator: AppCoordinator,
        foodService: FoodServiceProtocol,
        waterService: WaterTrackingServiceProtocol,
        goalsService: GoalsServiceProtocol,
        dailySummaryService: DailySummaryServiceProtocol,
        isGuest: Bool
    ) -> some View {
        let foodVM = FoodViewModel(coordinator: coordinator, service: foodService)
        let waterVM = WaterViewModel(coordinator: coordinator, service: waterService)
        let goalsVM = GoalsViewModel(coordinator: coordinator, service: goalsService)

        let homeVM = HomeViewModel(
            coordinator: coordinator,
            dailySummaryService: dailySummaryService,
            foodViewModel: foodVM,
            waterViewModel: waterVM,
            goalsViewModel: goalsVM,
            guestStore: isGuest ? GuestStore.shared : nil
        )
        HomeView(homeViewModel: homeVM, isGuest: isGuest)
    }
}
