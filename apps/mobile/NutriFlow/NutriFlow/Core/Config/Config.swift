
import Foundation

enum APIConfig {
    static let baseURL = "https://nutriflow-api-dev.onrender.com/api"
    static let amplitudeApiKey =
        Bundle.main.object(forInfoDictionaryKey: "AmplitudeApiKey") as? String ?? ""
}
