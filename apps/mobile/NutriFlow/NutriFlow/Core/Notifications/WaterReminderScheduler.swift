import Foundation

@MainActor
protocol WaterReminderScheduling: AnyObject {
    var isWaterReminderEnabled: Bool { get }
    var reminderTime: ReminderTime { get }

    func setWaterRemindersEnabled(_ isEnabled: Bool) async -> Bool
    func updateReminderTime(_ time: ReminderTime) async
    func ensureScheduledIfEnabled() async
    func syncTodayReminder() async
    func cancel()
}

@MainActor
final class WaterReminderScheduler: WaterReminderScheduling {
    private let notificationManager: NotificationManaging
    private let preferences: NotificationPreferences
    private let waterTrackingService: WaterTrackingServiceProtocol
    private let goalsService: GoalsServiceProtocol

    init(
        notificationManager: NotificationManaging,
        preferences: NotificationPreferences,
        waterTrackingService: WaterTrackingServiceProtocol,
        goalsService: GoalsServiceProtocol
    ) {
        self.notificationManager = notificationManager
        self.preferences = preferences
        self.waterTrackingService = waterTrackingService
        self.goalsService = goalsService
    }

    var isWaterReminderEnabled: Bool {
        preferences.waterRemindersEnabled
    }

    var reminderTime: ReminderTime {
        preferences.waterReminderTime
    }

    func setWaterRemindersEnabled(_ isEnabled: Bool) async -> Bool {
        guard isEnabled else {
            preferences.waterRemindersEnabled = false
            cancel()
            return true
        }

        guard await notificationManager.requestAuthorizationIfNeeded() else {
            return false
        }

        preferences.waterRemindersEnabled = true
        await syncTodayReminder()
        return true
    }

    func updateReminderTime(_ time: ReminderTime) async {
        preferences.waterReminderTime = time

        await syncTodayReminder()
    }

    func ensureScheduledIfEnabled() async {
        await syncTodayReminder()
    }

    func syncTodayReminder() async {
        guard isWaterReminderEnabled else {
            cancel()
            return
        }

        guard await notificationManager.requestAuthorizationIfNeeded() else { return }
        guard let reminderDate = todayReminderDate(), reminderDate > .now else {
            cancelPendingReminder()
            return
        }

        do {
            async let waterEntries = waterTrackingService.getTodayWater()
            async let goals = goalsService.getGoals()
            let (entries, userGoals) = try await (waterEntries, goals)

            guard let waterGoal = userGoals.dailyWaterGoal, waterGoal > 0 else {
                cancelPendingReminder()
                return
            }

            let totalWater = entries.reduce(0) { $0 + $1.amountMl }
            guard totalWater < waterGoal else {
                cancelPendingReminder()
                return
            }

            _ = await notificationManager.schedule(.waterReminder(at: reminderDate))
        } catch {
            #if DEBUG
            print("[Notifications] Failed to synchronize water reminder: \(error)")
            #endif
        }
    }

    func cancel() {
        notificationManager.cancel(identifiers: [AppNotification.waterReminderIdentifier])
    }

    private func cancelPendingReminder() {
        notificationManager.cancelPending(identifiers: [AppNotification.waterReminderIdentifier])
    }

    private func todayReminderDate() -> Date? {
        let time = reminderTime
        return Calendar.current.date(
            bySettingHour: time.hour,
            minute: time.minute,
            second: 0,
            of: .now
        )
    }
}
