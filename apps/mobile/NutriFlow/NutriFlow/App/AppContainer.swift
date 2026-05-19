import Foundation
import Combine

@MainActor
final class AppContainer: ObservableObject {

    let httpClient: HTTPClient
    let keychainService: KeychainService
    let tokenStorage: TokenStorageProtocol
    let sessionManager: SessionManager
    let authService: AuthServiceProtocol
    let profileService: ProfileServiceProtocol
    let userService: UserServiceProtocol
    let foodService: FoodServiceProtocol
    
    init() {
        self.httpClient = URLSessionHTTPClient()
        self.keychainService = KeychainService()
        self.tokenStorage = TokenStorage(keychain: keychainService)
        self.sessionManager = SessionManager(tokenStorage: tokenStorage)
        self.authService = AuthService(client: httpClient)
        self.profileService = ProfileService(client: httpClient)
        self.foodService = FoodService(client: httpClient)
        self.userService = UserService(client: httpClient)
    }

    func makeAuthViewModel() -> AuthViewModel {
        AuthViewModel(authService: authService, sessionManager: sessionManager)
    }

    func makeProfileViewModel() -> ProfileViewModel {
        ProfileViewModel(session: sessionManager, profileService: profileService, userService: userService)
    }
    
    func makeFoodViewModel() -> FoodViewModel {
        FoodViewModel(session: sessionManager ,service: foodService)
    }
}
