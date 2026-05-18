import Foundation

protocol AuthServiceProtocol {

    func register(
        email: String,
        password: String,
        firstName: String,
        lastName: String
    ) async throws -> AuthTokensResponse

    func login(
        email: String,
        password: String
    ) async throws -> AuthTokensResponse

    func refresh(
        refreshToken: String
    ) async throws -> AuthTokensResponse

    func logout(
        accessToken: String
    ) async throws -> LogoutResponse

    func logoutAll(
        accessToken: String
    ) async throws -> LogoutResponse
}
