import Foundation

@MainActor
final class AuthService: AuthServiceProtocol, Sendable {

    private let client: HTTPClient
    private let sessionService: AuthSessionService
    private let imageCacheService: ImageCacheServiceProtocol

    init(
        client: HTTPClient,
        sessionService: AuthSessionService,
        imageCacheService: ImageCacheServiceProtocol
    ) {
        self.client = client
        self.sessionService = sessionService
        self.imageCacheService = imageCacheService
    }

    func register(email: String, password: String, firstName: String, lastName: String) async throws {
        let request = APIRequest(
            path: AuthEndpoints.register,
            method: .POST,
            body: RegisterDTO(email: email, password: password, firstName: firstName, lastName: lastName)
        )

        let response: AuthTokensResponse = try await client.send(request)
        let sessionID = try sessionService.establishSession(access: response.accessToken, refresh: response.refreshToken)
        await imageCacheService.startPrivateSession(sessionId: sessionID)
    }

    func login(email: String, password: String) async throws {
        let request = APIRequest(
            path: AuthEndpoints.login,
            method: .POST,
            body: LoginDTO(email: email, password: password)
        )

        let response: AuthTokensResponse = try await client.send(request)
        let sessionID = try sessionService.establishSession(access: response.accessToken, refresh: response.refreshToken)
        await imageCacheService.startPrivateSession(sessionId: sessionID)
    }

    func signInWithGoogle(idToken: String) async throws {
        let request = APIRequest(
            path: AuthEndpoints.google,
            method: .POST,
            body: GoogleLoginDTO(idToken: idToken)
        )

        let response: AuthTokensResponse = try await client.send(request)
        let sessionID = try sessionService.establishSession(access: response.accessToken, refresh: response.refreshToken)
        await imageCacheService.startPrivateSession(sessionId: sessionID)
    }
    
    func signInWithApple(identityToken: String, firstName: String?, lastName: String?) async throws {
        let request = APIRequest(
            path: AuthEndpoints.apple,
            method: .POST,
            body: AppleLoginDTO(identityToken: identityToken, firstName: firstName, lastName: lastName)
        )
        
        let response: AuthTokensResponse = try await client.send(request)
        let sessionID = try sessionService.establishSession(access: response.accessToken, refresh: response.refreshToken)
        await imageCacheService.startPrivateSession(sessionId: sessionID)
    }

    func logout() async throws {
        // Logout is a local security boundary. Even if the server is
        // unreachable, this device must not retain a reusable session.
        let request = APIRequest<NeverBody>(
            path: AuthEndpoints.logout,
            method: .POST
        )

        do {
            try await client.sendVoid(request)
        } catch {
            await clearLocalSession()
            throw error
        }
        await clearLocalSession()
    }

    func logoutAll() async throws {
        let request = APIRequest<NeverBody>(
            path: AuthEndpoints.logoutAll,
            method: .POST
        )

        do {
            try await client.sendVoid(request)
        } catch {
            await clearLocalSession()
            throw error
        }
        await clearLocalSession()
    }
    
    func changePassword(currentPassword: String, newPassword: String) async throws {
        let request = APIRequest(
            path: AuthEndpoints.changePassword,
            method: .POST,
            body: ChangePasswordDTO(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
        )

        try await client.sendVoid(request)

        await clearLocalSession()
    }

    private func clearLocalSession() async {
        await imageCacheService.endPrivateSession()
        try? sessionService.clear()
    }
}
