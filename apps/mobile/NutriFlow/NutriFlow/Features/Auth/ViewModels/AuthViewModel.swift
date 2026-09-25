import AuthenticationServices
import Foundation
import Observation

@Observable
@MainActor
final class AuthViewModel {
    var state: AuthState = .idle
    var email = ""
    var password = ""
    var firstName = ""
    var lastName = ""

    var isLoading: Bool {
        state == .loading
    }

    @ObservationIgnored private let authService: AuthServiceProtocol
    @ObservationIgnored private let profileService: ProfileServiceProtocol
    @ObservationIgnored private let googleSignInService: GoogleSignInService
    @ObservationIgnored private let analyticsTracker: AnalyticsTracking?
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private var activitySync: ActivitySyncProtocol?

    init(
        authService: AuthServiceProtocol,
        profileService: ProfileServiceProtocol,
        googleSignInService: GoogleSignInService,
        coordinator: AppCoordinator,
        activitySync: ActivitySyncProtocol? = nil,
        analyticsTracker: AnalyticsTracking? = nil
    ) {
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
        guard validateCredentials() else { return }
        state = .loading

        do {
            try await authService.login(email: email, password: password)
            await finishSignIn()
        } catch {
            show(error: error, for: .credentials)
        }
    }

    func register() async {
        guard validateRegistration() else { return }
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
            show(error: error, for: .credentials)
        }
    }

    func signInWithGoogle() async {
        state = .loading

        do {
            let idToken = try await googleSignInService.signIn()
            try await authService.signInWithGoogle(idToken: idToken)
            await finishSignIn()
        } catch {
            show(error: error, for: .google)
        }
    }

    func signInWithApple(
        identityToken: String,
        firstName: String?,
        lastName: String?
    ) async {
        state = .loading

        do {
            try await authService.signInWithApple(
                identityToken: identityToken,
                firstName: firstName,
                lastName: lastName
            )
            await finishSignIn()
        } catch {
            show(error: error, for: .apple)
        }
    }

    func retry(_ operation: AuthOperation) async {
        switch operation {
        case .credentials:
            await login()
        case .google:
            await signInWithGoogle()
        case .apple:
            state = .idle
        }
    }

    func handleAppleAuthorizationError(_ error: Error) {
        show(error: error, for: .apple)
    }

    func handleMissingAppleToken() {
        state = .error(
            .validation(message: "Apple sign-in did not return an identity token."),
            operation: .apple
        )
    }

    func logout() async {
        activitySync?.stop()

        do {
            try await authService.logout()
        } catch {
            // A local logout must still complete if the remote request fails.
        }

        state = .unauthenticated
        analyticsTracker?.track(.loggedOut)
        coordinator?.goToAuth()
    }

    private func finishSignIn() async {
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
    }

    private func show(error: Error, for operation: AuthOperation) {
        let appError = ErrorMapper.map(error)
        state = appError == .cancelled
            ? .idle
            : .error(appError, operation: operation)
    }

    private func validateCredentials() -> Bool {
        guard email.trimmingCharacters(in: .whitespacesAndNewlines).contains("@") else {
            state = .error(
                .validation(message: "Enter a valid email address."),
                operation: .credentials
            )
            return false
        }

        guard !password.isEmpty else {
            state = .error(
                .validation(message: "Enter your password."),
                operation: .credentials
            )
            return false
        }

        return true
    }

    private func validateRegistration() -> Bool {
        guard validateCredentials() else { return false }

        guard !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            state = .error(
                .validation(message: "Enter your first name."),
                operation: .credentials
            )
            return false
        }

        guard !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            state = .error(
                .validation(message: "Enter your last name."),
                operation: .credentials
            )
            return false
        }

        return true
    }
}