enum ProgressFactory {
    @MainActor
    static func make(
        coordinator: AppCoordinator,
        container: AppDependency,
        periodState: PeriodState
    ) -> (AnalyticsViewModel, ProgressChartViewModel, GoalsViewModel) {
        let cache = container.cacheService
        let analyticsVM = AnalyticsViewModel(
            coordinator: coordinator,
            service: container.analyticsService,
            periodState: periodState,
            cacheService: cache
        )
        let chartVM = ProgressChartViewModel(
            coordinator: coordinator,
            service: container.dailySummaryService,
            periodState: periodState,
            foodService: container.foodService,
            waterService: container.waterTrackingService,
            goalsService: container.goalsService,
            activityService: container.activityService,
            cacheService: cache
        )
        let goalsVM = GoalsViewModel(
            coordinator: coordinator,
            service: container.goalsService,
            cacheService: cache
        )
        return (analyticsVM, chartVM, goalsVM)
    }
}
