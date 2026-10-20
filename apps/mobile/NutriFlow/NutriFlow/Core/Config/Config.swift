
import Foundation

enum APIConfig {
    static let baseURL: URL = {
            guard
                let value = Bundle.main.object(
                    forInfoDictionaryKey: "APIBaseURL"
                ) as? String,
                let url = URL(string: value)
            else {
                fatalError("APIBaseURL is missing or invalid")
            }

            return url
        }()
    
    static let amplitudeApiKey: String = {
            guard
                let key = Bundle.main.object(
                    forInfoDictionaryKey: "AmplitudeApiKey"
                ) as? String,
                !key.isEmpty
            else {
                fatalError("AmplitudeApiKey is missing or empty")
            }

            return key
        }()
}
