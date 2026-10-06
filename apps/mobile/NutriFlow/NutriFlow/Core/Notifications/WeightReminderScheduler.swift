import Foundation

@MainActor
protocol WeightReminderScheduling: AnyObject {
    var isWeightReminderEnabled: Bool { get }

    func setRemindersEnabled(_ isEnabled: Bool) async -> Bool
    func ensureScheduledIfEnabled() async
    func rescheduleAfterWeightUpdate() async
    func cancel()
}

@MainActor
final class WeightReminderScheduler: WeightReminderScheduling {
    private let reminderInterval: TimeInterval = 60
    private let notificationManager: NotificationManaging
    private let preferences: NotificationPreferences

    init(
        notificationManager: NotificationManaging,
        preferences: NotificationPreferences
    ) {
        self.notificationManager = notificationManager
        self.preferences = preferences
    }

    var isWeightReminderEnabled: Bool {
        preferences.weightRemindersEnabled
    }

    func setRemindersEnabled(_ isEnabled: Bool) async -> Bool {
        guard isEnabled else {
            preferences.weightRemindersEnabled = false
            cancel()
            return true
        }

        guard await notificationManager.requestAuthorizationIfNeeded() else {
            return false
        }

        preferences.weightRemindersEnabled = true
        await scheduleWeightReminder()
        return true
    }

    func ensureScheduledIfEnabled() async {
        guard isWeightReminderEnabled else { return }
        guard await notificationManager.requestAuthorizationIfNeeded() else { return }
        let hasPendingReminder = await notificationManager.hasPendingRequest(
            identifier: AppNotification.weightReminderIdentifier
        )
        guard !hasPendingReminder else {
            return
        }
        await scheduleWeightReminder()
    }

    func rescheduleAfterWeightUpdate() async {
        guard isWeightReminderEnabled else { return }
        await scheduleWeightReminder()
    }

    func cancel() {
        notificationManager.cancel(identifiers: [AppNotification.weightReminderIdentifier])
    }

    private func scheduleWeightReminder() async {
        await notificationManager.schedule(.weightReminder(after: reminderInterval))
    }
}
