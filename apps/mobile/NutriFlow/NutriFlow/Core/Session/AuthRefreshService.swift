import Foundation

enum AuthError: Error {
    case noSession
    case sessionExpired
}

extension Notification.Name {
    static let sessionExpired = Notification.Name("sessionExpired")
}

final class AuthRefreshService: Sendable {

    private let client: HTTPClient
    private let session: AuthSessionService

    init(client: HTTPClient, session: AuthSessionService) {
        self.client = client
        self.session = session
    }

    func refresh() async throws {
        guard let refresh = session.getRefreshToken() else {
            throw AuthError.noSession
        }

        let request = APIRequest(
            path: AuthEndpoints.refresh,
            method: .POST,
            body: RefreshDTO(refreshToken: refresh)
        )

        do {
            let response: AuthTokensResponse = try await client.send(request)
            session.saveSession(access: response.accessToken,
                                refresh: response.refreshToken)
        } catch {
            session.clear()
            NotificationCenter.default.post(name: .sessionExpired, object: nil)
            throw AuthError.sessionExpired
        }
    }
}
