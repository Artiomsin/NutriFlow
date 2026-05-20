import SwiftUI

struct SettingsTabFlow: View {
    @Bindable var session: SessionManager

    var body: some View {
        AppTheme.background.ignoresSafeArea()
            .overlay(SettingsView(session: session))
    }
}