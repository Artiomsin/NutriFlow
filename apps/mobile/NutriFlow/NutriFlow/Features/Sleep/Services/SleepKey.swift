import Foundation

enum SleepKey {

    static func dayKey(_ date: Date) -> String {
        AppDate.dateOnlyFormatter().string(from: date)
    }

    static func nightKey(_ night: HealthKitSleep) -> String {
        dayKey(night.startDate)
    }

    static func parseISODate(_ string: String) -> Date? {
        if let date = SleepMapper.isoFormatter.date(from: string) {
            return date
        }

        return fractionalFormatter.date(from: string)
    }

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        return formatter
    }()
}
