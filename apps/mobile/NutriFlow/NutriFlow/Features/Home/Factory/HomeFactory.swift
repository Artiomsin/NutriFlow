import SwiftUI

enum HomeFactory {
    @MainActor @ViewBuilder
    static func make(
        coordinator: AppCoordinator,
        container: AppDependency,
        isGuest: Bool
    ) -> some View {
        let foodVM = FoodViewModel(coordinator: coordinator, service: container.foodService)
        let waterVM = WaterViewModel(coordinator: coordinator, service: container.waterTrackingService)
        let goalsVM = GoalsViewModel(coordinator: coordinator, service: container.goalsService)

        let homeVM = HomeViewModel(
            coordinator: coordinator,
            dailySummaryService: container.dailySummaryService,
            foodViewModel: foodVM,
            waterViewModel: waterVM,
            goalsViewModel: goalsVM,
            guestStore: isGuest ? GuestStore.shared : nil
        )
        HomeView(homeViewModel: homeVM, isGuest: isGuest)
    }
}
