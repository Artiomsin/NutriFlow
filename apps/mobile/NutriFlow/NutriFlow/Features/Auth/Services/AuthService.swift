import Foundation

final class AuthService: AuthServiceProtocol, Sendable {

    private let client: HTTPClient
    private let sessionService: AuthSessionService

    init(client: HTTPClient, sessionService: AuthSessionService) {
        self.client = client
        self.sessionService = sessionService
    }

    func register(email: String, password: String, firstName: String, lastName: String) async throws {
        let request = APIRequest(
            path: AuthEndpoints.register,
            method: .POST,
            body: RegisterDTO(email: email, password: password, firstName: firstName, lastName: lastName)
        )

        let response: AuthTokensResponse = try await client.send(request)
        sessionService.saveSession(access: response.accessToken, refresh: response.refreshToken)
    }

    func login(email: String, password: String) async throws {
        let request = APIRequest(
            path: AuthEndpoints.login,
            method: .POST,
            body: LoginDTO(email: email, password: password)
        )

        let response: AuthTokensResponse = try await client.send(request)
        sessionService.saveSession(access: response.accessToken, refresh: response.refreshToken)
    }

    func logout() async throws {
        let request = APIRequest<NeverBody>(
            path: AuthEndpoints.logout,
            method: .POST
        )

        try await client.sendVoid(request)
        sessionService.clear()
    }

    func logoutAll() async throws {
        let request = APIRequest<NeverBody>(
            path: AuthEndpoints.logoutAll,
            method: .POST
        )

        try await client.sendVoid(request)
        sessionService.clear()
    }

    func refresh(refreshToken: String) async throws -> AuthTokensResponse {
        let request = APIRequest(
            path: AuthEndpoints.refresh,
            method: .POST,
            body: RefreshDTO(refreshToken: refreshToken)
        )
        return try await client.send(request)
    }
}
