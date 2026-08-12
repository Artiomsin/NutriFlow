enum HomeFactory {
    @MainActor
    static func make(
        coordinator: AppCoordinator,
        container: AppDependency
    ) -> HomeViewModel {
        let cache = container.cacheService
        let todayFoodVM = TodayFoodViewModel(service: container.foodService, coordinator: coordinator, cacheService: cache)
        let waterVM = WaterViewModel(coordinator: coordinator, service: container.waterTrackingService, cacheService: cache)
        let goalsVM = GoalsViewModel(coordinator: coordinator, service: container.goalsService, cacheService: cache)

        return HomeViewModel(
            coordinator: coordinator,
            dailySummaryService: container.dailySummaryService,
            foodService: container.foodService,
            todayFoodVM: todayFoodVM,
            waterVM: waterVM,
            goalsVM: goalsVM,
            cacheService: cache
        )
    }
}
