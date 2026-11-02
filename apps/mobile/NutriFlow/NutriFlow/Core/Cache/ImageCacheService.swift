import Foundation
import Kingfisher

struct ImageLoadingConfiguration {
    let cache: ImageCache
    let downloader: ImageDownloader
    let requestModifier: (any ImageDownloadRequestModifier)?
}

@MainActor
final class ImageCacheService: ImageCacheServiceProtocol {

    private struct PrivateSession {
        let id: UUID
        let cache: ImageCache
        let downloader: ImageDownloader
        let requestModifier: PrivateImageRequestModifier
    }

    private let sessionService: AuthSessionService
    private let apiBaseURL: URL
    private let publicCache = ImageCache(name: "nutriflow.public")
    private let publicDownloader = ImageDownloader(name: "nutriflow.public.downloader")
    private var privateSession: PrivateSession?

    init(
        sessionService: AuthSessionService,
        apiBaseURL: URL = APIConfig.baseURL
    ) {
        self.sessionService = sessionService
        self.apiBaseURL = apiBaseURL
    }

    func publicConfiguration() -> ImageLoadingConfiguration {
        ImageLoadingConfiguration(
            cache: publicCache,
            downloader: publicDownloader,
            requestModifier: nil
        )
    }

    func startPrivateSession(sessionId: UUID) async {
        guard privateSession?.id != sessionId else {
            return
        }

        await endPrivateSession()

        let cache = ImageCache(name: "nutriflow.private.(sessionId.uuidString)")
        let downloader = ImageDownloader(name: "nutriflow.private.downloader.(sessionId.uuidString)")
        downloader.downloadTimeout = 30

        privateSession = PrivateSession(
            id: sessionId,
            cache: cache,
            downloader: downloader,
            requestModifier: PrivateImageRequestModifier(
                session: sessionService,
                apiBaseURL: apiBaseURL
            )
        )
    }

    func privateConfiguration() -> ImageLoadingConfiguration? {
        guard let session = privateSession else {
            return nil
        }

        return ImageLoadingConfiguration(
            cache: session.cache,
            downloader: session.downloader,
            requestModifier: session.requestModifier
        )
    }

    func endPrivateSession() async {
        guard let oldSession = privateSession else {
            return
        }

        // Make stale view instances unable to acquire this configuration first.
        privateSession = nil
        oldSession.downloader.cancelAll()
        oldSession.cache.clearMemoryCache()

        await withCheckedContinuation { continuation in
            oldSession.cache.clearDiskCache {
                continuation.resume()
            }
        }
    }
}
