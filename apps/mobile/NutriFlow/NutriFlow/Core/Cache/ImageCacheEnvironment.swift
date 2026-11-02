import SwiftUI

private struct ImageCacheServiceKey: EnvironmentKey {
    static let defaultValue: (any ImageCacheServiceProtocol)? = nil
}

extension EnvironmentValues {
    var imageCacheService: (any ImageCacheServiceProtocol)? {
        get { self[ImageCacheServiceKey.self] }
        set { self[ImageCacheServiceKey.self] = newValue }
    }
}
