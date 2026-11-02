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
        } catch APIError.notFound {
            return .profileForm
        } catch APIError.unauthorized, APIError.forbidden {
            try sessionService.clear()
            return .auth
        } catch {
            let appError = ErrorMapper.map(error)

            // A temporary failure does not prove that credentials are invalid.
            // Keep the session and surface the mapped error on the main screen.
            return .main(
                bootstrapError: appError == .cancelled ? nil : appError
            )
        }
    }
}
