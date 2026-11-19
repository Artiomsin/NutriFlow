import Foundation

@MainActor
enum SettingsFactory {
    static func makeProfileViewModel(
        container: AppDependency,
        coordinator: AppCoordinator,
        progressRefreshState: ProgressRefreshState
    ) -> ProfileViewModel {
        ProfileViewModel(
            coordinator: coordinator,
            authService: container.authService,
            profileService: container.profileService,
            userService: container.userService,
            cacheService: container.cacheService,
            progressRefreshState: progressRefreshState,
            activitySync: container.activitySync,
            analyticsTracker: container.analyticsTracker,
            weightReminderScheduler: container.weightReminderScheduler,
            waterReminderScheduler: container.waterReminderScheduler
        )
    }
}
