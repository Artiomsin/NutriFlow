import SwiftUI
import Kingfisher

/// Loads images through the cache namespace that matches the URL's access level.
struct NutriflowImage: View {
    let url: URL

    @Environment(\.imageCacheService) private var imageCacheService

    var body: some View {
        if let configuration {
            image(configuration)
        } else {
            EmptyView()
        }
    }

    private var configuration: ImageLoadingConfiguration? {
        guard let imageCacheService else {
            return nil
        }

        if ImageURLResolver.isPrivateUploadURL(url) {
            return imageCacheService.privateConfiguration()
        }

        return imageCacheService.publicConfiguration()
    }

    private func image(_ configuration: ImageLoadingConfiguration) -> some View {
        var image = KFImage(url)
            .targetCache(configuration.cache)
            .downloader(configuration.downloader)

        if let requestModifier = configuration.requestModifier {
            image = image.requestModifier(requestModifier)
        }

        if let retryStrategy = configuration.retryStrategy {
            image = image.retry(retryStrategy)
        }

        return image
            .fade(duration: 0.25)
            .resizable()
            .scaledToFill()
    }
}
