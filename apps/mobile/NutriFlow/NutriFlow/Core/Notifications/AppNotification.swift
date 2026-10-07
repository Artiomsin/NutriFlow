import Foundation

enum AppNotificationTrigger: Sendable {
    case timeInterval(TimeInterval, repeats: Bool)
    case calendar(DateComponents, repeats: Bool)
    case immediate
}
enum AppNotificationGroup: Sendable{
    
    case reminders
    case achievements
    
    var threadIdentifier: String {
        switch self {
        case .reminders:
            "notifications.reminders"
        case .achievements:
            "notifications.achievements"
        }
    }
}

struct AppNotification: Sendable {
    static let userInfoTypeKey = "notification_type"
    
    
    let identifier: String
    let type: AppNotificationType
    let title: String
    let body: String
    let trigger: AppNotificationTrigger
    let threadIdentifier: String
    
    static let weightReminderIdentifier = "notification.weight_reminder"
    static let waterReminderIdentifier = "notification.water_reminder"
    static let achievementBatchIdentifier = "notification.achievement.batch"
    
    static func weightReminder(
        after interval: TimeInterval
    ) -> AppNotification {
        AppNotification(
            identifier: weightReminderIdentifier,
            type: .weightReminder,
            title: "NutriFlow",
            body: "Изменился ли ваш вес? Обновите его, чтобы отслеживать прогресс.",
            trigger: .timeInterval(
                interval,
                repeats: true
            ),
            threadIdentifier: AppNotificationGroup.reminders.threadIdentifier
        )
    }
    
    static func waterReminder(at date: Date) -> AppNotification {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        
        return AppNotification(
            identifier: waterReminderIdentifier,
            type: .waterReminder,
            title: "NutriFlow",
            body: "Не забудьте пополнить дневной запас воды.",
            trigger: .calendar(components, repeats: false),
            threadIdentifier: AppNotificationGroup.reminders.threadIdentifier
        )
    }
    
    static func achievement(
        achievements: [Achievement],
        after interval: TimeInterval
    ) -> AppNotification {
        let sorted = achievements.sorted { $0.id < $1.id }

        let title: String
        let body: String

        if sorted.count == 1, let only = sorted.first {
            title = only.title
            body = only.body
        } else {
            title = "NutriFlow"
            let count = sorted.count
            let items = sorted
                .map { "• \($0.title)" }
                .joined(separator: "\n")
            body = "Сегодня выполнено \(count) целей:\n\(items)"
        }

        return AppNotification(
            identifier: achievementBatchIdentifier,
            type: .achievement,
            title: title,
            body: body,
            trigger: .timeInterval(interval, repeats: false),
            threadIdentifier: AppNotificationGroup.achievements.threadIdentifier
        )
    }
}
