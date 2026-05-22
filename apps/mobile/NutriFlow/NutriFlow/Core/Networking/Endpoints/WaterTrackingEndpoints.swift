import Foundation

enum WaterTrackingEndpoints {

    static let createWaterTracking = "/water-tracking"
    static let getTodayWater = "/water-tracking/today"

    static func deleteWaterTracking(id: String) -> String {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        return "/water-tracking/\(encoded)"
    }
}
