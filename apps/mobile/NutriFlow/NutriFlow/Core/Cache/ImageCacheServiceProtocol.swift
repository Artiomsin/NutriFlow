import Foundation
import Kingfisher

@MainActor
protocol ImageCacheServiceProtocol {
    func publicConfiguration() -> ImageLoadingConfiguration
    func startPrivateSession(sessionId: UUID) async
    func privateConfiguration() -> ImageLoadingConfiguration?
    func endPrivateSession() async
}
