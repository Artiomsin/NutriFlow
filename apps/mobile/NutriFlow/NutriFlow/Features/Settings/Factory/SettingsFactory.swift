import SwiftUI

enum SettingsFactory {
    @MainActor @ViewBuilder
    static func make(container: AppDependency, coordinator: AppCoordinator) -> some View {
        let viewModel = ProfileViewModel(
            coordinator: coordinator,
            authService: container.authService,
            profileService: container.profileService,
            userService: container.userService
        )
        SettingsView(viewModel: viewModel)
    }
}
