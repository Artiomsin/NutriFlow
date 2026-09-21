import Foundation

enum SessionBootstrapResult: Sendable {
    case auth
    case profileForm
    case main
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
            return .main
        } catch APIError.notFound {
            return .profileForm
        } catch {
            try sessionService.clear()
            return .auth
        }
    }
}
