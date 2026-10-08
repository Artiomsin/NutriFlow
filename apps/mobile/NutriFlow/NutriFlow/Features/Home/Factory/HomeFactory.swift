enum HomeFactory {
    @MainActor
    static func make(
        coordinator: AppCoordinator,
        container: AppDependency,
        progressRefreshState: ProgressRefreshState
    ) -> HomeViewModel {
        let cache = container.cacheService

        let goalsVM = GoalsViewModel(
            coordinator: coordinator,
            service: container.goalsService,
            cacheService: cache,
            progressRefreshState: progressRefreshState
        )

        let goalsProvider: () -> UserGoals? = {
            if case .loaded(let goals) = goalsVM.state {
                return goals
            }
            return nil
        }

        container.activitySync.goalsProvider = goalsProvider

        let todayFoodVM = TodayFoodViewModel(
            service: container.foodService,
            coordinator: coordinator,
            cacheService: cache,
            progressRefreshState: progressRefreshState,
            goalsService: container.goalsService,
            goalsProvider: goalsProvider,
            achievementService: container.achievementService,
            achievementNotificationService: container.achievementNotificationService
        )
        let waterVM = WaterViewModel(
            coordinator: coordinator,
            service: container.waterTrackingService,
            cacheService: cache,
            progressRefreshState: progressRefreshState,
            analyticsTracker: container.analyticsTracker,
            goalsService: container.goalsService,
            goalsProvider: goalsProvider,
            achievementService: container.achievementService,
            achievementNotificationService: container.achievementNotificationService
        )
        let activityVM = ActivityViewModel(
            healthKit: container.activityHealthKitService
        )
        let workoutVM = WorkoutViewModel(
            healthKit: container.workoutHealthKitService,
            workoutService: container.workoutService,
            cacheService: cache,
            analyticsTracker: container.analyticsTracker,
            goalsService: container.goalsService,
            goalsProvider: goalsProvider,
            achievementService: container.achievementService,
            achievementNotificationService: container.achievementNotificationService
        )
        let sleepVM = SleepViewModel(
            coordinator: container.sleepSync,
            analyticsTracker: container.analyticsTracker,
            goalsService: container.goalsService,
            goalsProvider: goalsProvider,
            achievementService: container.achievementService,
            achievementNotificationService: container.achievementNotificationService
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
            cacheService: cache,
            progressRefreshState: progressRefreshState
        )
    }
}
