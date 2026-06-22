import Foundation
import Observation

@Observable
@MainActor
final class AuthViewModel {

    var state: AuthState = .idle
    var email: String = ""
    var password: String = ""
    var firstName: String = ""
    var lastName: String = ""

    @ObservationIgnored private let authService: AuthServiceProtocol
    @ObservationIgnored private let profileService: ProfileServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?

    init(authService: AuthServiceProtocol, profileService: ProfileServiceProtocol, coordinator: AppCoordinator) {
        self.authService = authService
        self.profileService = profileService
        self.coordinator = coordinator
    }

    func login() async {
        state = .loading

        do {
            try await authService.login(email: email, password: password)

            do {
                _ = try await profileService.getMyProfile()
                coordinator?.goToMain()
            } catch let profileError as APIError {
                if case .notFound = profileError {
                    coordinator?.goToProfileForm()
                } else {
                    coordinator?.goToMain()
                }
            } catch {
                coordinator?.goToMain()
            }

            state = .authenticated
            AnalyticsManager.shared.track(.loggedIn)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func register() async {
        state = .loading

        do {
            try await authService.register(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName
            )
            state = .authenticated
            AnalyticsManager.shared.track(.registered)
            coordinator?.goToProfileForm()
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func logout() async {
        do {
            try await authService.logout()
            state = .unauthenticated
            AnalyticsManager.shared.track(.loggedOut)
            coordinator?.goToAuth()
        } catch {
            state = .unauthenticated
            AnalyticsManager.shared.track(.loggedOut)
            coordinator?.goToAuth()
        }
    }
    
    deinit {
           print("AuthViewModel УНИЧТОЖЕН!")
       }
}
