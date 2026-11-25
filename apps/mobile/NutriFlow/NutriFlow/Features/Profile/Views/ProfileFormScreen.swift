import SwiftUI

@MainActor
struct ProfileFormScreen: View {
    @State private var profileViewModel: ProfileViewModel
    @State private var reviewViewModel: InitialPlanReviewViewModel

    init(container: AppDependency, coordinator: AppCoordinator) {
        _profileViewModel = State(
            initialValue: ProfileViewModel(
                coordinator: coordinator,
                authService: container.authService,
                profileService: container.profileService,
                userService: container.userService,
                cacheService: container.cacheService,
                activitySync: container.activitySync,
                analyticsTracker: container.analyticsTracker,
                weightReminderScheduler: container.weightReminderScheduler,
                waterReminderScheduler: container.waterReminderScheduler
            )
        )
        _reviewViewModel = State(
            initialValue: InitialPlanReviewViewModel(
                coordinator: coordinator,
                service: container.goalsService,
                cacheService: container.cacheService
            )
        )
    }

    var body: some View {
        ProfileOnboardingView(
            viewModel: profileViewModel,
            reviewViewModel: reviewViewModel
        )
    }
}
