import SwiftUI

struct ProfileTabFlow: View {

    @ObservedObject var profileViewModel: ProfileViewModel

    @EnvironmentObject var session: SessionManager

    var onLogout: (() -> Void)?

    var body: some View {

        ZStack {

            AppTheme.background
                .ignoresSafeArea()

            ProfileDisplayView(
                viewModel: profileViewModel,
                onLogout: onLogout
            )
        }
    }
}
