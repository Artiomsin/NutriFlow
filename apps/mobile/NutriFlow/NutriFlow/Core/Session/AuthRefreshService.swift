import Foundation

enum AuthError: Error {
    case noSession
    case sessionExpired
}

extension Notification.Name {
    static let sessionExpired = Notification.Name("sessionExpired")
}

actor AuthRefreshService: Sendable {

    private let client: HTTPClient
    private let session: AuthSessionService

    private var inFlight: Task<Void, Error>?

    init(client: HTTPClient, session: AuthSessionService) {
        self.client = client
        self.session = session
    }

    func refresh() async throws {
        if let inFlight {
            return try await inFlight.value
        }

        let task = Task { try await performRefresh() }
        inFlight = task
        defer {
            if inFlight === task {
                inFlight = nil
            }
        }
        return try await task.value
    }

    private func performRefresh() async throws {
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
