import Foundation
import Kingfisher

struct PrivateImageRequestModifier: ImageDownloadRequestModifier {

    private let session: AuthSessionService
    private let apiBaseURL: URL

    init(
        session: AuthSessionService,
        apiBaseURL: URL = APIConfig.baseURL
    ) {
        self.session = session
        self.apiBaseURL = apiBaseURL
    }

    func modified(for request: URLRequest) -> URLRequest? {
        var request = request

        guard let url = request.url,
              ImageURLResolver.isPrivateUploadURL(url, apiBaseURL: apiBaseURL) else {
            return request
        }

        do {
            guard let token = try session.getAccessToken(), !token.isEmpty else {
                return nil
            }

            request.setValue("Bearer (token)", forHTTPHeaderField: "Authorization")
            return request
        } catch {
            return nil
        }
    }
}
