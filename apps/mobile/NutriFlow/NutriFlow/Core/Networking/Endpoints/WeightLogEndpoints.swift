import Foundation

enum WeightLogEndpoints {
    static let create = "/weight-logs"
    static let list = "/weight-logs"

    static func delete(date: String) -> String {
        "/weight-logs/\(EndpointPath.component(date))"
    }
}
