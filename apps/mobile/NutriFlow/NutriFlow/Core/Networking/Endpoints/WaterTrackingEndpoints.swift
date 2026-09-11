import Foundation

enum WaterTrackingEndpoints {

    static let createWaterTracking = "/water-tracking"

    static func getTodayWater(date: String?) -> (path: String, query: [URLQueryItem]) {
        (path: "/water-tracking/today", query: date.map { [URLQueryItem(name: "date", value: $0)] } ?? [])
    }

    static func deleteWaterTracking(id: String, date: String?) -> (path: String, query: [URLQueryItem]) {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        return (path: "/water-tracking/\(encoded)", query: date.map { [URLQueryItem(name: "date", value: $0)] } ?? [])
    }
    static func getWaterByDate(date: String) -> (path: String, query: [URLQueryItem]) {
        (path: "/water-tracking", query: [URLQueryItem(name: "date", value: date)])
    }
}
