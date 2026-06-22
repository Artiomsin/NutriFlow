import SwiftUI

enum SettingsFactory {
    @MainActor @ViewBuilder
    static func make(profileViewModel: ProfileViewModel) -> some View {
        SettingsView(viewModel: profileViewModel)
    }
}
