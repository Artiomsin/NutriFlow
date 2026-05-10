import SwiftUI

enum AppScreen {
    case auth
    case profileForm
    case home
}

struct AppRootView: View {
    
    @StateObject private var session = SessionManager()
    @StateObject private var profileVM = ProfileViewModel()
    @State private var currentScreen: AppScreen = .auth
    @State private var profileCompleted = false
    @State private var showErrorAlert = false
    @State private var currentError: Error?
    
    var body: some View {
        
        ZStack {
            
            Color(red: 0.03, green: 0.04, blue: 0.06)
                .ignoresSafeArea()
            
            switch currentScreen {
                
            case .auth:
                AuthView(session: session)
                    .onChange(of: session.state) { _, newState in
                        if case .authenticated = newState {
                            profileVM.configure(session: session)
                            Task {
                                await checkProfile()
                            }
                        }
                    }
                
            case .profileForm:
                ProfileFormView(viewModel: ProfileViewModel(session: session), isCompleted: $profileCompleted)
                    .onChange(of: profileCompleted) { _, completed in
                        if completed {
                            currentScreen = .home
                        }
                    }
                
            case .home:
                HomeView()
                    .environmentObject(session)
            }
        }
        .onChange(of: session.state) { _, newState in
            if case .unauthenticated = newState {
                currentScreen = .auth
            }
            if case .error(let error) = newState {
                currentError = error
                
                if let apiError = error as? APIError, case .unauthorized = apiError {
                    session.logout()
                    currentScreen = .auth
                } else {
                    showErrorAlert = true
                }
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("Retry") {
                Task {
                    await session.restoreSession()
                }
            }
            Button("Logout", role: .destructive) {
                session.logout()
                currentScreen = .auth
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(currentError?.localizedDescription ?? "Unknown error")
        }
    }
    
    private func checkProfile() async {
        await profileVM.loadProfile()
        
        switch profileVM.state {
        case .loaded:
            currentScreen = .home
        case .empty, .error:
            currentScreen = .profileForm
        case .loading, .saving:
            break
        }
    }
}

#Preview {
    AppRootView()
}