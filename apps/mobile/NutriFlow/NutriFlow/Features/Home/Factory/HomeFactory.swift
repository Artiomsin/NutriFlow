import SwiftUI

enum HomeFactory {
    @MainActor @ViewBuilder
    static func make(
        coordinator: AppCoordinator,
        container: AppDependency,
        isGuest: Bool
    ) -> some View {
        let cache = container.cacheService
        let foodVM = FoodViewModel(coordinator: coordinator, service: container.foodService, cacheService: cache)
        let waterVM = WaterViewModel(coordinator: coordinator, service: container.waterTrackingService, cacheService: cache)
        let goalsVM = GoalsViewModel(coordinator: coordinator, service: container.goalsService, cacheService: cache)

        let homeVM = HomeViewModel(
            coordinator: coordinator,
            dailySummaryService: container.dailySummaryService,
            foodViewModel: foodVM,
            waterViewModel: waterVM,
            goalsViewModel: goalsVM,
            guestStore: isGuest ? GuestStore.shared : nil,
            cacheService: cache
        )
        HomeView(homeViewModel: homeVM, isGuest: isGuest)
    }
}
