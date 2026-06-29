import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: ProfileViewModel
    let coordinator: AppCoordinator?
    @State private var showProfile = false

    var body: some View {
        let _ = print("SettingsView body")
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {

                Text("Settings")
                    .font(Font.h1)
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.top, AppTheme.headerPaddingTop)

                Spacer()
                    .frame(height: 20)

                VStack(spacing: 16) {
                    if coordinator?.isGuest == true {
                        Button {
                            coordinator?.goToAuth()
                        } label: {
                            SettingsRow(icon: "person", title: "Login or Register")
                        }
                    } else {
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
                }
                .padding(.horizontal, AppTheme.paddingHorizontal)

                Spacer()
                    .frame(height: 100)
            }
        }
        .refreshable { await viewModel.loadData() }
        .task {
            AnalyticsManager.shared.track(.screenView(screen: "settings"))
            await viewModel.loadData()
        }
        .fullScreenCover(isPresented: $showProfile) {
            ProfileDisplayView(viewModel: viewModel)
        }
    }
}
