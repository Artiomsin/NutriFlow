import SwiftUI

struct ProfileTabView: View {
    @Bindable var viewModel: ProfileViewModel
    @Bindable var session: SessionManager
    var onLogout: (() -> Void)?
    
    var body: some View {
        ProfileDisplayView(viewModel: viewModel, session: session, onLogout: onLogout)
            .onAppear {
                Task {
                    await viewModel.loadData()
                }
            }
    }
}