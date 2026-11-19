import SwiftUI

@MainActor
struct AuthScreen: View {
    @State private var viewModel: AuthViewModel

    init(container: AppDependency, coordinator: AppCoordinator) {
        _viewModel = State(
            initialValue: AuthViewModel(
                authService: container.authService,
                googleSignInService: container.googleSignInService,
                coordinator: coordinator,
                activitySync: container.activitySync,
                analyticsTracker: container.analyticsTracker
            )
        )
    }

    var body: some View {
        AuthView(viewModel: viewModel)
    }
}
