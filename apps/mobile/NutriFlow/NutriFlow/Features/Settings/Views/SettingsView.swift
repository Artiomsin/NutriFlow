import SwiftUI

struct SettingsView: View {
    @Bindable var session: SessionManager

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {

                Text("Settings")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.top, AppTheme.headerPaddingTop)

                Spacer()
                    .frame(height: 20)

                VStack(spacing: 16) {
                    SettingsRow(icon: "person", title: "Account")
                    SettingsRow(icon: "bell", title: "Notifications")
                    SettingsRow(icon: "lock", title: "Privacy")
                }
                .padding(.horizontal, AppTheme.paddingHorizontal)

                Spacer()
                    .frame(height: 100)
            }
        }
    }
}