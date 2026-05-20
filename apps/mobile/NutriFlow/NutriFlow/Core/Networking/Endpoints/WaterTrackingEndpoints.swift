import Foundation

enum WaterTrackingEndpoints {

    static let createWaterTracking = "/water-tracking"
    static let getTodayWater = "/water-tracking/today"

    static func deleteWaterTracking(id: String) -> String {
        "/water-tracking/\(id)"
    }
}
