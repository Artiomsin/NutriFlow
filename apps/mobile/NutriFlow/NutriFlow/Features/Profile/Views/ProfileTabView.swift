import SwiftUI

struct ProfileTabView: View {
    @ObservedObject var viewModel: ProfileViewModel
    var onLogout: (() -> Void)?
    
    var body: some View {
        ProfileDisplayView(viewModel: viewModel, onLogout: onLogout)
            .onAppear {
                Task {
                    await viewModel.loadData()
                }
            }
    }
}
