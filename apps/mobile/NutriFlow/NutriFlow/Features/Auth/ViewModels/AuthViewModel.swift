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
    @ObservationIgnored private let googleSignInService: GoogleSignInService
    @ObservationIgnored private let analyticsTracker: AnalyticsTracking?
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private var activitySync: ActivitySyncProtocol?

    init(authService: AuthServiceProtocol, profileService: ProfileServiceProtocol, googleSignInService: GoogleSignInService, coordinator: AppCoordinator, activitySync: ActivitySyncProtocol? = nil, analyticsTracker: AnalyticsTracking? = nil) {
        self.authService = authService
        self.profileService = profileService
        self.googleSignInService = googleSignInService
        self.analyticsTracker = analyticsTracker
        self.coordinator = coordinator
        self.activitySync = activitySync
    }

    func onAppear() {
        analyticsTracker?.track(.screenView(screen: "auth"))
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
            analyticsTracker?.track(.loggedIn)
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
            analyticsTracker?.track(.registered)
            coordinator?.goToProfileForm()
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    func signInWithGoogle() async {
        state = .loading
        
        do {
            let idToken = try await googleSignInService.signIn()
            try await authService.signInWithGoogle(idToken: idToken)
            
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
            analyticsTracker?.track(.loggedIn)
        } catch let error as GoogleSignInError {
            if case .cancelled = error {
                state = .idle
            } else {
                state = .error(error.localizedDescription)
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    func signInWithApple(identityToken: String, firstName: String?, lastName: String?) async {
        state = .loading

        do {
            try await authService.signInWithApple(identityToken: identityToken, firstName: firstName, lastName: lastName)
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
            analyticsTracker?.track(.loggedIn)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    


func logout() async {
    activitySync?.stop()
    do {
        try await authService.logout()
        state = .unauthenticated
        analyticsTracker?.track(.loggedOut)
        coordinator?.goToAuth()
    } catch {
        state = .unauthenticated
        analyticsTracker?.track(.loggedOut)
        coordinator?.goToAuth()
    }
}

deinit {
    print("AuthViewModel УНИЧТОЖЕН!")
}
}
