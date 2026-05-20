import SwiftUI

struct ProfileTabFlow: View {

    @Bindable var profileViewModel: ProfileViewModel
    @Bindable var session: SessionManager
    var onLogout: (() -> Void)?

    var body: some View {

        ZStack {

            AppTheme.background
                .ignoresSafeArea()

            ProfileDisplayView(
                viewModel: profileViewModel,
                session: session,
                onLogout: onLogout
            )
        }
    }
}