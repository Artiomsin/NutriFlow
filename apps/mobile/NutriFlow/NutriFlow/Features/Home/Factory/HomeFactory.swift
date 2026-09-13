enum HomeFactory {
    @MainActor
    static func make(
        coordinator: AppCoordinator,
        container: AppDependency,
        progressRefreshState: ProgressRefreshState
    ) -> HomeViewModel {
        let cache = container.cacheService
        let todayFoodVM = TodayFoodViewModel(service: container.foodService, coordinator: coordinator, cacheService: cache, progressRefreshState: progressRefreshState)
        let waterVM = WaterViewModel(coordinator: coordinator, service: container.waterTrackingService, cacheService: cache, progressRefreshState: progressRefreshState, analyticsTracker: container.analyticsTracker)
        let goalsVM = GoalsViewModel(coordinator: coordinator, service: container.goalsService, cacheService: cache)
        let activityVM = ActivityViewModel(
            healthKit: container.activityHealthKitService
        )
        let workoutVM = WorkoutViewModel(
            healthKit: container.workoutHealthKitService,
            workoutService: container.workoutService,
            cacheService: cache,
            analyticsTracker: container.analyticsTracker
        )
        let sleepVM = SleepViewModel(
            coordinator: container.sleepSync,
            analyticsTracker: container.analyticsTracker
        )
        
        return HomeViewModel(
            coordinator: coordinator,
            dailySummaryService: container.dailySummaryService,
            foodService: container.foodService,
            todayFoodVM: todayFoodVM,
            waterVM: waterVM,
            goalsVM: goalsVM,
            activityVM: activityVM,
            workoutVM: workoutVM,
            sleepVM: sleepVM,
            activitySync: container.activitySync,
            cacheService: cache
        )
    }
}
