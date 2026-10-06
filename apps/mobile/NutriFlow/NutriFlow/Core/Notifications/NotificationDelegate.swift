import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private static let pendingNotificationTypeKey = "pendingNotificationType"

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        let userInfo = response.notification.request.content.userInfo
        guard
            let rawType = userInfo[AppNotification.userInfoTypeKey] as? String,
            let type = AppNotificationType(rawValue: rawType)
        else {
            return
        }

        // Do not mutate SwiftUI navigation state in this delegate callback.
        // UIKit is still restoring the application's snapshot at this point.
        UserDefaults.standard.set(type.rawValue, forKey: Self.pendingNotificationTypeKey)
    }

    static func consumePendingNotificationType() -> AppNotificationType? {
        let defaults = UserDefaults.standard
        defer { defaults.removeObject(forKey: pendingNotificationTypeKey) }

        guard let rawType = defaults.string(forKey: pendingNotificationTypeKey) else {
            return nil
        }
        return AppNotificationType(rawValue: rawType)
    }
}
