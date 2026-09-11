import Foundation

struct SleepSyncEntry: Codable, Sendable {
    let startDate: String
    let endDate: String
    let timeInBedSeconds: Double?
    let asleepSeconds: Double?
    let awakeSeconds: Double?
    let coreSeconds: Double?
    let deepSeconds: Double?
    let remSeconds: Double?
    let unspecifiedSeconds: Double?
    let awakenings: Int?
    let onsetLatencySeconds: Double?
    let efficiency: Double?
    let segmentCount: Int?
    let heartRateAvg: Double?
}

struct SleepHistoryResponse: Codable, Sendable {
    let total: Int
    let nights: [SleepSyncEntry]
}