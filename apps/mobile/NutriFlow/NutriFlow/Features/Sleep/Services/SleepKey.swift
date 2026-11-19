import Foundation

enum SleepKey {

    static func dayKey(_ date: Date) -> String {
        AppDate.dateOnlyFormatter().string(from: date)
    }

    /// Sessions are identified by their exact start/end, not by calendar day:
    /// a nap and the following night can share a day but are separate entries.
    static func nightKey(_ night: HealthKitSleep) -> String {
        night.id.uuidString
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
