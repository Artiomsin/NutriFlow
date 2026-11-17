import Foundation

struct Achievement: Sendable, Equatable {
    let id: String
    let title: String
    let body: String

    /// Single source for date-suffixed achievement ids (`prefix_YYYY-MM-DD`).
    /// Shared by AchievementService (generates ids) and
    /// AchievementNotificationService (prunes them).
    /// Computed so an in-app profile time-zone change is reflected immediately.
    static var dayFormatter: DateFormatter {
        AppDate.dateOnlyFormatter()
    }
}
