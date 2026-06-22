import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: ProfileViewModel
    @State private var showProfile = false

    var body: some View {
        let _ = print("SettingsView body")
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {

                Text("Settings")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.top, AppTheme.headerPaddingTop)

                Spacer()
                    .frame(height: 20)

                VStack(spacing: 16) {
                    Button {
                        showProfile = true
                    } label: {
                        SettingsRow(icon: "person", title: "Profile")
                    }

                    Button {
                        Task { await viewModel.logout() }
                    } label: {
                        SettingsRow(icon: "arrow.right.square", title: "Logout")
                    }
                }
                .padding(.horizontal, AppTheme.paddingHorizontal)

                Spacer()
                    .frame(height: 100)
            }
        }
        .task {
            AnalyticsManager.shared.track(.screenView(screen: "settings"))
            await viewModel.loadData()
        }
        .fullScreenCover(isPresented: $showProfile) {
            ProfileDisplayView(viewModel: viewModel)
        }
    }
}
