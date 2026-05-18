import SwiftUI

struct ProfileTabFlow: View {

    @ObservedObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var session: SessionManager
    var onLogout: (() -> Void)?

    var body: some View {
        ProfileDisplayView(
            viewModel: profileViewModel,
            onLogout: onLogout
        )
        .background(AppTheme.background)
    }
}
