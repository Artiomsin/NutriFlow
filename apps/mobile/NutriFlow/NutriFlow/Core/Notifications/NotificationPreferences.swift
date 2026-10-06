import Foundation
import Observation

@MainActor
@Observable
final class NotificationPreferences {
    private enum Key {
        static let weightRemindersEnabled = "notifications.weightRemindersEnabled"
        static let waterRemindersEnabled = "notifications.waterRemindersEnabled"
        static let waterReminderHour = "notifications.waterReminderHour"
        static let waterReminderMinute = "notifications.waterReminderMinute"
        
        static let legacyRemindersEnabled = "notifications.remindersEnabled"
    }

    var weightRemindersEnabled: Bool {
        didSet {
            UserDefaults.standard.set(weightRemindersEnabled, forKey: Key.weightRemindersEnabled)
        }
    }

    var waterRemindersEnabled: Bool {
        didSet {
            UserDefaults.standard.set(waterRemindersEnabled, forKey: Key.waterRemindersEnabled)
        }
    }

    var waterReminderTime: ReminderTime {
        didSet {
            UserDefaults.standard.set(waterReminderTime.hour, forKey: Key.waterReminderHour)
            UserDefaults.standard.set(waterReminderTime.minute, forKey: Key.waterReminderMinute)
        }
    }

    init() {
        let defaults = UserDefaults.standard
        weightRemindersEnabled = defaults.object(forKey: Key.weightRemindersEnabled) as? Bool
            ?? defaults.object(forKey: Key.legacyRemindersEnabled) as? Bool
            ?? false
        waterRemindersEnabled = defaults.object(forKey: Key.waterRemindersEnabled) as? Bool ?? false
        waterReminderTime = ReminderTime(
            hour: defaults.object(forKey: Key.waterReminderHour) as? Int
                ?? ReminderTime.defaultWaterReminder.hour,
            minute: defaults.object(forKey: Key.waterReminderMinute) as? Int
                ?? ReminderTime.defaultWaterReminder.minute
        )
    }
}
