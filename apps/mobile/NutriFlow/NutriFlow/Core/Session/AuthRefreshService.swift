import Foundation

enum AuthRefreshError: Error, Sendable, AppErrorConvertible {
    case noSession
    case sessionExpired

    var appError: AppError {
        .sessionExpired
    }
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

        let task: Task<Void, Error> = Task { try await performRefresh() }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }

    func invalidateSession() {
        expireSession()
    }

    private func performRefresh() async throws {
        guard let refreshToken = try session.getRefreshToken() else {
            expireSession()
            throw AuthRefreshError.noSession
        }

        let request = APIRequest(
            path: AuthEndpoints.refresh,
            method: .POST,
            body: RefreshDTO(refreshToken: refreshToken)
        )

        let response: AuthTokensResponse
        do {
            response = try await client.send(request)
        } catch APIError.unauthorized {
            expireSession()
            throw AuthRefreshError.sessionExpired
        } catch APIError.forbidden {
            expireSession()
            throw AuthRefreshError.sessionExpired
        }

        try session.saveSession(
            access: response.accessToken,
            refresh: response.refreshToken
        )
    }

    private func expireSession() {
        try? session.clear()
        NotificationCenter.default.post(name: .sessionExpired, object: nil)
    }
}
