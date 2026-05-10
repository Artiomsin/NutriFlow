import SwiftUI

struct ProfileTabView: View {
    @EnvironmentObject var session: SessionManager
    @StateObject private var profileVM = ProfileViewModel()
    
    var body: some View {
        ProfileDisplayView(viewModel: profileVM)
            .onAppear {
                profileVM.configure(session: session)
                Task {
                    await profileVM.loadProfile()
                }
            }
    }
}