import SwiftUI

enum AppScreen: Equatable {
    case auth
    case profileForm
    case home
}

struct AppRootView: View {

    @State private var container: AppContainer
    @State private var authViewModel: AuthViewModel
    @State private var profileViewModel: ProfileViewModel
    @State private var homeViewModel: HomeViewModel
    @State private var currentScreen: AppScreen = .auth
    @State private var profileCompleted = false

    init() {
        let container = AppContainer()
        _container = State(wrappedValue: container)
        _authViewModel = State(wrappedValue: container.makeAuthViewModel())
        _profileViewModel = State(wrappedValue: container.makeProfileViewModel())
        _homeViewModel = State(wrappedValue: container.makeHomeViewModel())
    }
    
    var body: some View {
        
        ZStack {
            
            AppTheme.background
                .ignoresSafeArea()
            
            switch currentScreen {
                
            case .auth:
                AuthView(viewModel: authViewModel)
                    .onChange(of: container.sessionManager.state) { oldState, newState in
                        if newState == .authenticated {
                            Task {
                                await handleAuthSuccess()
                            }
                        }
                    }
                
            case .profileForm:
                ProfileFormView(viewModel: profileViewModel, isCompleted: $profileCompleted)
                    .onChange(of: profileCompleted) { _, newValue in
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
                    homeViewModel: homeViewModel,
                    profileViewModel: profileViewModel,
                    session: container.sessionManager
                )
            }
        }
        .onChange(of: container.sessionManager.state) { oldState, newState in
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
                        await handleAuthSuccess()
                    } else {
                        currentScreen = .auth
                    }
                }
            }
        }
    }
    
    private func handleAuthSuccess() async {
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