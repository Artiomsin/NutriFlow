import Foundation

struct Achievement: Sendable, Equatable {
    let id: String
    let title: String
    let body: String

    /// Single source for date-suffixed achievement ids (`prefix_YYYY-MM-DD`).
    /// Shared by AchievementService (generates ids) and
    /// AchievementNotificationService (prunes them).
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()
}
