import Foundation

enum SleepMapper {

    static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func isoString(from date: Date) -> String {
        isoFormatter.string(from: date)
    }

    static func toEntry(_ sleep: HealthKitSleep) -> SleepSyncEntry {
        SleepSyncEntry(
            startDate: isoString(from: sleep.startDate),
            endDate: isoString(from: sleep.endDate),
            timeInBedSeconds: sleep.timeInBedSeconds,
            asleepSeconds: sleep.asleepSeconds,
            awakeSeconds: sleep.awakeSeconds,
            coreSeconds: sleep.coreSeconds,
            deepSeconds: sleep.deepSeconds,
            remSeconds: sleep.remSeconds,
            unspecifiedSeconds: sleep.unspecifiedSeconds,
            awakenings: sleep.awakenings,
            onsetLatencySeconds: sleep.onsetLatencySeconds,
            efficiency: sleep.efficiency,
            segmentCount: sleep.segmentCount,
            heartRateAvg: sleep.heartRateAvg
        )
    }
}