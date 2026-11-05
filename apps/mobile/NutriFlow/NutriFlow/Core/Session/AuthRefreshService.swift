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
    private let imageCacheService: ImageCacheServiceProtocol
    private var inFlight: Task<Void, Error>?

    init(
        client: HTTPClient,
        session: AuthSessionService,
        imageCacheService: ImageCacheServiceProtocol
    ) {
        self.client = client
        self.session = session
        self.imageCacheService = imageCacheService
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

    func invalidateSession() async {
        await expireSession()
    }

    private func performRefresh() async throws {
        guard let refreshToken = try session.getRefreshToken() else {
            await expireSession()
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
            await expireSession()
            throw AuthRefreshError.sessionExpired
        } catch APIError.forbidden {
            await expireSession()
            throw AuthRefreshError.sessionExpired
        }

        do {
            try session.updateTokens(
                access: response.accessToken,
                refresh: response.refreshToken
            )
        } catch {
            await expireSession()
            throw AuthRefreshError.sessionExpired
        }
    }

    private func expireSession() async {
        await imageCacheService.endPrivateSession()
        try? session.clear()
        NotificationCenter.default.post(name: .sessionExpired, object: nil)
    }
}
