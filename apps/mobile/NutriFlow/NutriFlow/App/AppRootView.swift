import SwiftUI


enum AppScreen: Equatable {
    case auth
    case profileForm
    case home
}

struct AppRootView: View {
    
    @StateObject private var container = AppContainer()
    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var profileViewModel: ProfileViewModel
    @StateObject private var foodViewModel: FoodViewModel
    @State private var currentScreen: AppScreen = .auth
    @State private var profileCompleted = false
    
    init() {
        let container = AppContainer()
        _container = StateObject(wrappedValue: container)
        _authViewModel = StateObject(wrappedValue: container.makeAuthViewModel())
        _profileViewModel = StateObject(wrappedValue: container.makeProfileViewModel())
        _foodViewModel = StateObject(wrappedValue: container.makeFoodViewModel())
    }
    
    var body: some View {
        
        ZStack {
            
            Color.clear
                .background(AppTheme.background.ignoresSafeArea())
            
            switch currentScreen {
                
            case .auth:
                AuthView(viewModel: authViewModel)
                    .onChange(of: container.sessionManager.state) { (oldState: SessionState, newState: SessionState) in
                        if newState == .authenticated {
                            Task {
                                await checkProfile()
                            }
                        }
                    }
                
            case .profileForm:
                ProfileFormView(viewModel: profileViewModel, isCompleted: $profileCompleted)
                    .onChange(of: profileCompleted) { (oldValue: Bool, newValue: Bool) in
                        if newValue {
                            currentScreen = .home
                        }
                    }
                
            case .home:
                HomeView(
                    onLogout: {
                        authViewModel.email = ""
                        authViewModel.password = ""
                        authViewModel.firstName = ""
                        authViewModel.lastName = ""
                        Task {
                            await authViewModel.logout()
                        }
                        currentScreen = .auth
                    },
                    profileViewModel: profileViewModel,
                    foodViewModel: foodViewModel
                )
                    .environmentObject(container.sessionManager)
            }
        }
        .onChange(of: container.sessionManager.state) { (oldState: SessionState, newState: SessionState) in
            if newState == .unauthenticated {
                currentScreen = .auth
            }
        }
        .onAppear {
           
            profileViewModel.onUnauthorized = { [self] in
                currentScreen = .auth
            }
            
            let sessionState = container.sessionManager.state
            if sessionState == .authenticated {
                Task {
                    let isValid = await authViewModel.refreshTokenIfNeeded()
                    if isValid {
                        await checkProfile()
                    } else {
                        currentScreen = .auth
                    }
                }
            }
        }
    }
    
    private func checkProfile() async {
        await profileViewModel.loadData()
        
        switch profileViewModel.state {
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
