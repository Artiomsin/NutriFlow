import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    
    @Published private(set) var state: AuthState = .idle
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    
    private let authService: AuthServiceProtocol
    private let sessionManager: SessionManager
    
    init(
        authService: AuthServiceProtocol,
        sessionManager: SessionManager
    ) {
        self.authService = authService
        self.sessionManager = sessionManager

        if case .authenticated = sessionManager.state {
            self.state = .authenticated
        } else {
            self.state = .unauthenticated
        }
    }


    func login() async {
        state = .loading

        do {
            let response = try await authService.login(email: email, password: password)

            sessionManager.setSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken
            )

            state = .authenticated

        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func register() async {
        state = .loading

        do {
            let response = try await authService.register(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName
            )

            sessionManager.setSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken
            )

            state = .authenticated

        } catch {
            state = .error(error.localizedDescription)
        }
    }


    func logout() async {
        guard let token = sessionManager.accessToken() else {
            sessionManager.logout()
            state = .unauthenticated
            return
        }

        do {
            _ = try await authService.logout(accessToken: token)
            sessionManager.logout()
            state = .unauthenticated
        } catch {
            sessionManager.logout()
            state = .unauthenticated
        }
    }


    func refreshTokenIfNeeded() async -> Bool {
        guard let refreshToken = sessionManager.refreshToken() else {
            return false
        }

        do {
            let response = try await authService.refresh(refreshToken: refreshToken)

            sessionManager.setSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken
            )

            return true
        } catch {
            sessionManager.logout()
            return false
        }
    }
}
