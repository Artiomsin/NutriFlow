import Foundation

enum AppNotificationTrigger: Sendable {
    case timeInterval(TimeInterval, repeats: Bool)
    case calendar(DateComponents, repeats: Bool)
}

struct AppNotification: Sendable {
    static let userInfoTypeKey = "notification_type"
    

    let identifier: String
    let type: AppNotificationType
    let title: String
    let body: String
    let trigger: AppNotificationTrigger

    static let weightReminderIdentifier = "notification.weight_reminder"
    static let waterReminderIdentifier = "notification.water_reminder"
    
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
                )
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
            trigger: .calendar(components, repeats: false)
        )
    }
    
}
