import Foundation

final class AuthService: AuthServiceProtocol {

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func register(email: String, password: String, firstName: String, lastName: String) async throws -> AuthTokensResponse {

        let request = APIRequest(
            path: AuthEndpoints.register,
            method: .POST,
            body: RegisterDTO(email: email, password: password, firstName: firstName, lastName: lastName)
        )

        return try await client.send(request)
    }

    func login(email: String, password: String) async throws -> AuthTokensResponse {

        let request = APIRequest(
            path: AuthEndpoints.login,
            method: .POST,
            body: LoginDTO(email: email, password: password)
        )

        return try await client.send(request)
    }

    func refresh(refreshToken: String) async throws -> AuthTokensResponse {

        let request = APIRequest(
            path: AuthEndpoints.refresh,
            method: .POST,
            body: RefreshDTO(refreshToken: refreshToken)
        )

        return try await client.send(request)
    }

    func logout(accessToken: String) async throws -> LogoutResponse {

        let request = APIRequest<EmptyBody>(
            path: AuthEndpoints.logout,
            method: .POST,
            body: EmptyBody(),
            headers: ["Authorization": "Bearer \(accessToken)"]
        )

        return try await client.send(request)
    }

    func logoutAll(accessToken: String) async throws -> LogoutResponse {

        let request = APIRequest<EmptyBody>(
            path: AuthEndpoints.logoutAll,
            method: .POST,
            body: EmptyBody(),
            headers: ["Authorization": "Bearer \(accessToken)"]
        )

        return try await client.send(request)
    }
}
