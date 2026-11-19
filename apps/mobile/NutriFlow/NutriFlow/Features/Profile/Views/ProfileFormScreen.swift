import SwiftUI

@MainActor
struct ProfileFormScreen: View {
    @State private var viewModel: ProfileViewModel

    init(container: AppDependency, coordinator: AppCoordinator) {
        _viewModel = State(
            initialValue: ProfileViewModel(
                coordinator: coordinator,
                authService: container.authService,
                profileService: container.profileService,
                userService: container.userService,
                activitySync: container.activitySync,
                analyticsTracker: container.analyticsTracker,
                weightReminderScheduler: container.weightReminderScheduler,
                waterReminderScheduler: container.waterReminderScheduler
            )
        )
    }

    var body: some View {
        ProfileFormView(viewModel: viewModel)
    }
}
