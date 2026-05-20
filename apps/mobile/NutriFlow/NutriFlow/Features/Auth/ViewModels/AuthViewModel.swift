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
    @ObservationIgnored private let sessionManager: SessionManager
    
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