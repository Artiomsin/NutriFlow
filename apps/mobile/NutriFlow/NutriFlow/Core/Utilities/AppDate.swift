import Foundation

/// Calendar helpers anchored to the user's profile time zone.
///
/// The API stores entries and resolves goal versions by calendar day in this
/// zone, so every date string and day-level comparison on the client must use
/// the same calendar. Reading `TimeZone.current` here would silently shift days
/// whenever the device zone differs from the profile zone, for example when the
/// person keeps a fixed time zone while travelling.
enum AppDate {
    /// Time zone configured in the profile, mirrored in `PreferencesStore`.
    static var timeZone: TimeZone {
        TimeZone(identifier: PreferencesStore.shared.timeZone) ?? .current
    }

    /// Gregorian calendar in the profile time zone.
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .current
        calendar.timeZone = timeZone
        return calendar
    }

    /// Formatter for the `yyyy-MM-dd` strings exchanged with the API.
    ///
    /// Created per call because the profile time zone can change while the app
    /// is running (manual setting or automatic travel updates).
    static func dateOnlyFormatter() -> DateFormatter {
        makeFormatter("yyyy-MM-dd", locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Formatter for human-readable labels, still anchored to the profile zone.
    static func displayFormatter(_ format: String) -> DateFormatter {
        makeFormatter(format, locale: .current)
    }

    private static func makeFormatter(
        _ format: String,
        locale: Locale
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = format
        formatter.timeZone = timeZone
        return formatter
    }
}
