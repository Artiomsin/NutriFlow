import SwiftUI

enum SettingsFactory {
    @MainActor @ViewBuilder
    static func make(profileViewModel: ProfileViewModel, coordinator: AppCoordinator? = nil) -> some View {
        SettingsView(viewModel: profileViewModel, coordinator: coordinator)
    }
}
