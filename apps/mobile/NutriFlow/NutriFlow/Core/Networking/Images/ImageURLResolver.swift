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
        return apiURL(for: rawValue)
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
            effectivePort(for: url) == effectivePort(for: apiBaseURL)
        else {
            return false
        }

        let uploadPath = apiPath(for: "/uploads", apiBaseURL: apiBaseURL)
        return url.path == uploadPath || url.path.hasPrefix(uploadPath + "/")
    }

    private static func apiURL(for path: String) -> URL? {
        guard var components = URLComponents(
            url: APIConfig.baseURL,
            resolvingAgainstBaseURL: false
        ) else {
            return nil
        }

        components.percentEncodedPath = apiPath(for: path, apiBaseURL: APIConfig.baseURL)
        return components.url
    }

    private static func apiPath(for path: String, apiBaseURL: URL) -> String {
        let basePath = apiBaseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let suffix = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if basePath.isEmpty || suffix == basePath || suffix.hasPrefix(basePath + "/") {
            return "/" + suffix
        }

        return "/" + [basePath, suffix].joined(separator: "/")
    }

    private static func effectivePort(for url: URL) -> Int? {
        if let port = url.port {
            return port
        }

        switch url.scheme?.lowercased() {
        case "https":
            return 443
        case "http":
            return 80
        default:
            return nil
        }
    }
}
