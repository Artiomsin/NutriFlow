import Foundation

enum WorkoutEndpoints {
    static let sync = "/workouts/sync"
    static let deleteMissing = "/workouts/missing"

    static func history(
        from: String? = nil,
        to: String? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) -> (path: String, query: [URLQueryItem]) {
        var query: [URLQueryItem] = []
        if let from {
            query.append(URLQueryItem(name: "from", value: from))
        }
        if let to {
            query.append(URLQueryItem(name: "to", value: to))
        }
        if let limit {
            query.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let offset {
            query.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        return (path: "/workouts", query: query)
    }
}