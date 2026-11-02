import Foundation

enum ImageURLResolver {

    static func resolve(_ rawValue: String) -> URL? {
        guard !rawValue.isEmpty else { return nil }

        if let url = URL(string: rawValue),
           let scheme = url.scheme,
           ["http", "https"].contains(scheme.lowercased()),
           url.host != nil {
            return url
        }

        guard rawValue.hasPrefix("/") else { return nil }

        guard
            let scheme = APIConfig.baseURL.scheme,
            let host = APIConfig.baseURL.host
        else {
            return nil
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = APIConfig.baseURL.port
        components.path = rawValue

        return components.url
    }

    static func isPrivateUploadURL(
        _ url: URL,
        apiBaseURL: URL = APIConfig.baseURL
    ) -> Bool {
        guard
            let apiHost = apiBaseURL.host,
            let imageHost = url.host,
            imageHost.caseInsensitiveCompare(apiHost) == .orderedSame,
            url.scheme?.caseInsensitiveCompare(apiBaseURL.scheme ?? "") == .orderedSame,
            url.port == apiBaseURL.port
        else {
            return false
        }

        return url.path.hasPrefix("/api/uploads/")
    }
}
