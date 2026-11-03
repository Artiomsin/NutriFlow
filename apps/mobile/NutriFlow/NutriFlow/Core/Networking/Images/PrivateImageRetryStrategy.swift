import Foundation
import Kingfisher

/// Refreshes credentials once when a protected image request receives 401,
/// then lets Kingfisher repeat the original request with the fresh token.
struct PrivateImageRetryStrategy: RetryStrategy {
    private let refreshService: AuthRefreshService

    init(refreshService: AuthRefreshService) {
        self.refreshService = refreshService
    }

    func retry(
        context: RetryContext,
        retryHandler: @escaping @Sendable (RetryDecision) -> Void
    ) {
        guard
            context.retriedCount == 0,
            context.error.isInvalidResponseStatusCode(401)
        else {
            retryHandler(.stop)
            return
        }

        Task {
            do {
                try await refreshService.refresh()
                retryHandler(.retry(userInfo: nil))
            } catch {
                retryHandler(.stop)
            }
        }
    }
}
