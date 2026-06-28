enum HomeFactory {
    @MainActor
    static func make(
        coordinator: AppCoordinator,
        container: AppDependency,
        isGuest: Bool
    ) -> HomeViewModel {
        let cache = container.cacheService
        let foodVM = FoodViewModel(coordinator: coordinator, service: container.foodService, cacheService: cache)
        let waterVM = WaterViewModel(coordinator: coordinator, service: container.waterTrackingService, cacheService: cache)
        let goalsVM = GoalsViewModel(coordinator: coordinator, service: container.goalsService, cacheService: cache)

        return HomeViewModel(
            coordinator: coordinator,
            dailySummaryService: container.dailySummaryService,
            foodViewModel: foodVM,
            waterViewModel: waterVM,
            goalsViewModel: goalsVM,
            guestStore: isGuest ? GuestStore.shared : nil,
            cacheService: cache
        )
    }
}
