import Foundation

final class AuthTokenInterceptor: RequestInterceptor {

    private let session: AuthSessionService

    init(session: AuthSessionService) {
        self.session = session
    }

    func adapt(_ request: inout URLRequest) async throws {
        if let token = try session.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
}
