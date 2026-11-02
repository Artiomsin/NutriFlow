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

    
    var fieldErrors = FormFieldErrors()

    var isLoading: Bool {
        state == .loading
    }

    @ObservationIgnored
    private let authService: AuthServiceProtocol

    @ObservationIgnored
    private let googleSignInService: GoogleSignInService

    @ObservationIgnored
    private let analyticsTracker: AnalyticsTracking?

    @ObservationIgnored
    private weak var coordinator: AppCoordinator?

    @ObservationIgnored
    private var activitySync: ActivitySyncProtocol?

    init(
        authService: AuthServiceProtocol,
        googleSignInService: GoogleSignInService,
        coordinator: AppCoordinator,
        activitySync: ActivitySyncProtocol? = nil,
        analyticsTracker: AnalyticsTracking? = nil
    ) {
        self.authService = authService
        self.googleSignInService = googleSignInService
        self.analyticsTracker = analyticsTracker
        self.coordinator = coordinator
        self.activitySync = activitySync
    }

    // MARK: - Lifecycle

    func onAppear() {
        analyticsTracker?.track(.screenView(screen: "auth"))
    }

    func login() async {
        guard validateCredentials() else {
            state = .idle
            return
        }

        state = .loading

        do {
            try await authService.login(
                email: email,
                password: password
            )

            await completeAuthentication()

        } catch {
            show(error: error, for: .login)
        }
    }

    func register() async {
        guard validateRegistration() else {
            state = .idle
            return
        }

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
            show(error: error, for: .register)
        }
    }

    
    func signInWithGoogle() async {
        fieldErrors.removeAll()
        state = .loading

        do {
            let idToken = try await googleSignInService.signIn()

            try await authService.signInWithGoogle(
                idToken: idToken
            )

            await completeAuthentication()

        } catch {
            show(error: error, for: .google)
        }
    }

    func signInWithApple(
        identityToken: String,
        firstName: String?,
        lastName: String?
    ) async {
        fieldErrors.removeAll()
        state = .loading

        do {
            try await authService.signInWithApple(
                identityToken: identityToken,
                firstName: firstName,
                lastName: lastName
            )

            await completeAuthentication()

        } catch {
            show(error: error, for: .apple)
        }
    }

    func handleAppleAuthorizationError(_ error: Error) {
        show(error: error, for: .apple)
    }

    func handleMissingAppleToken() {
        fieldErrors.removeAll()

        state = .error(
            .invalidResponse,
            operation: .apple
        )
    }

    

    func retry(_ operation: AuthOperation) async {
        switch operation {
        case .login:
            await login()

        case .register:
            await register()
            
        case .google:
            await signInWithGoogle()

        case .apple:
            // Apple authorization must be initiated again
            // through the system authorization flow.
            state = .idle
        }
    }

    func logout() async {
        activitySync?.stop()

        do {
            try await authService.logout()
        } catch {
            // Local logout must complete even if
            // the remote request fails.
        }

        fieldErrors.removeAll()
        state = .unauthenticated

        analyticsTracker?.track(.loggedOut)
        coordinator?.goToAuth()
    }

    private func completeAuthentication() async {
        guard let result = await coordinator?.resolveSessionRoute() else {
            return
        }

        switch result {
        case .auth:
            state = .unauthenticated

        case .profileForm, .main:
            state = .authenticated
            analyticsTracker?.track(.loggedIn)
        }
    }


    
    private func show(
        error: Error,
        for operation: AuthOperation
    ) {
        let supportedFields: Set<String>

        switch operation {
        case .login:
            supportedFields = ["email", "password"]

        case .register:
            supportedFields = [
                "email",
                "password",
                "firstName",
                "lastName"
            ]

        case .google, .apple:
            supportedFields = []
        }

        switch ErrorHandler.handle(
            error,
            supportedFields: supportedFields
        ) {

        case .fieldErrors(let errors):
            fieldErrors = errors
            state = .idle

        case .general(let appError):
            fieldErrors.removeAll()

            if appError == .cancelled {
                state = .idle
                return
            }

            state = .error(
                appError,
                operation: operation
            )
        }
    }


    func clearFieldError(_ field: String) {
        fieldErrors.clear(field)
    }
    
    private func validateCredentials() -> Bool {
        fieldErrors.removeAll()

        let normalizedEmail = email.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if normalizedEmail.isEmpty {
            fieldErrors.set(
                FormErrorMapper.message(
                    for: FieldErrorCode.required.rawValue
                ),
                for: "email"
            )

        } else if !normalizedEmail.contains("@") {
            fieldErrors.set(
                FormErrorMapper.message(
                    for: FieldErrorCode.invalidEmail.rawValue
                ),
                for: "email"
            )
        }

        if password.isEmpty {
            fieldErrors.set(
                FormErrorMapper.message(
                    for: FieldErrorCode.required.rawValue
                ),
                for: "password"
            )
        }

        return fieldErrors.isEmpty
    }

    private func validateRegistration() -> Bool {
        let credentialsValid = validateCredentials()

        if firstName.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty {
            fieldErrors.set(
                FormErrorMapper.message(
                    for: FieldErrorCode.required.rawValue
                ),
                for: "firstName"
            )
        }

        if lastName.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty {
            fieldErrors.set(
                FormErrorMapper.message(
                    for: FieldErrorCode.required.rawValue
                ),
                for: "lastName"
            )
        }

        return credentialsValid && fieldErrors.isEmpty
    }
}
