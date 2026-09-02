
import Foundation

enum APIConfig {
    static let baseURL = "http://MacBook-Pro.local:3000/api"
    static let amplitudeApiKey =
        Bundle.main.object(forInfoDictionaryKey: "AmplitudeApiKey") as? String ?? ""
}
