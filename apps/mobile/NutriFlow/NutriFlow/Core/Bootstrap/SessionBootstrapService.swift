import Foundation

enum SessionBootstrapResult: Sendable, Equatable {
    case auth
    case profileForm
    case main(bootstrapError: AppError?)
}

final class SessionBootstrapService: Sendable {

    private let profileService: ProfileServiceProtocol
    private let sessionService: AuthSessionService

    init(
        profileService: ProfileServiceProtocol,
        sessionService: AuthSessionService
    ) {
        self.profileService = profileService
        self.sessionService = sessionService
    }

    func restoreSession() async throws -> SessionBootstrapResult {
        guard try sessionService.getRefreshToken() != nil else {
            return .auth
        }

        do {
            _ = try await profileService.getMyProfile()
            return .main(bootstrapError: nil)
        } catch {
            // The server returns Problem Details for 404/401/403, and the HTTP
            // client decodes those into APIError.remote rather than the status
            // cases, so match on the status code instead of the error case.
            if let apiError = error as? APIError {
                switch apiError.statusCode {
                case 404:
                    return .profileForm
                case 401, 403:
                    try sessionService.clear()
                    return .auth
                default:
                    break
                }
            }

            let appError = ErrorMapper.map(error)

            // A temporary failure does not prove that credentials are invalid.
            // Keep the session and surface the mapped error on the main screen.
            return .main(
                bootstrapError: appError == .cancelled ? nil : appError
            )
        }
    }
}
