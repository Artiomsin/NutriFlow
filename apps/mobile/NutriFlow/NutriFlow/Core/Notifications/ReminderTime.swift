import Foundation

struct ReminderTime: Codable, Hashable, Sendable {
    var hour: Int
    var minute: Int

    static let defaultWaterReminder = ReminderTime(hour: 20, minute: 0)
}
