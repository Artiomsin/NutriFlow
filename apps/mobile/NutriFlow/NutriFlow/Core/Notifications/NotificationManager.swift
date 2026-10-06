import UserNotifications

@MainActor
final class NotificationManager: NotificationManaging {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func hasPendingRequest(identifier: String) async -> Bool {
        let requests = await center.pendingNotificationRequests()
        return requests.contains { $0.identifier == identifier }
    }

    func schedule(_ notification: AppNotification) async {
        guard await requestAuthorizationIfNeeded() else { return }

        center.removePendingNotificationRequests(withIdentifiers: [notification.identifier])

        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        content.userInfo = [AppNotification.userInfoTypeKey: notification.type.rawValue]

        let trigger: UNNotificationTrigger
        switch notification.trigger {
        case let .timeInterval(interval, repeats):
            trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: interval,
                repeats: repeats
            )
        case let .calendar(dateComponents, repeats):
            trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: repeats
            )
        }

        let request = UNNotificationRequest(
            identifier: notification.identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            #if DEBUG
            print("[Notifications] Failed to schedule \(notification.identifier): \(error)")
            #endif
        }
    }

    func cancelPending(identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func cancel(identifiers: [String]) {
        cancelPending(identifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}
