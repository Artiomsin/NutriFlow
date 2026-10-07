//
//  AchievementNotificationService.swift
//  Nutriflow
//
//  Created by Artem on 06.10.2026.
//

import Foundation

@MainActor
final class AchievementNotificationService {

    private enum Key {
        static let notifiedAchievements =
            "notifications.notifiedAchievements"
    }

    private let notificationManager: NotificationManaging
    private let preferences: NotificationPreferences
    private let defaults: UserDefaults
    private let aggregationWindow: TimeInterval
    private let retentionDays: Int

    private var pending: [Achievement] = []
    private var batchStartedAt: Date?
    private var batchExpiryTask: Task<Void, Never>?

    init(
        notificationManager: NotificationManaging,
        preferences: NotificationPreferences,
        defaults: UserDefaults = .standard,
        aggregationWindow: TimeInterval = 20,
        retentionDays: Int = 5
    ) {
        self.notificationManager = notificationManager
        self.preferences = preferences
        self.defaults = defaults
        self.aggregationWindow = aggregationWindow
        self.retentionDays = retentionDays
    }

    var isAchievementNotificationsEnabled: Bool {
        preferences.achievementNotificationsEnabled
    }

    func setAchievementNotificationsEnabled(_ isEnabled: Bool) async -> Bool {
        guard isEnabled else {
            preferences.achievementNotificationsEnabled = false
            clearBatch(cancelScheduledNotification: true)
            return true
        }

        guard await notificationManager.requestAuthorizationIfNeeded() else {
            return false
        }

        preferences.achievementNotificationsEnabled = true
        return true
    }

    /// Removes notification state that belongs to the current signed-in user.
    /// This prevents a queued or previously recorded achievement from leaking
    /// into the next account on the same device.
    func clearSessionState() {
        clearBatch(cancelScheduledNotification: true)
        defaults.removeObject(forKey: Key.notifiedAchievements)
    }

    func notifyIfNeeded(achievement: Achievement) async {
        await notifyIfNeeded(achievements: [achievement])
    }

    func notifyIfNeeded(achievements: [Achievement]) async {
        guard isAchievementNotificationsEnabled else {
            #if DEBUG
            print("[AchievementNotification] skipped reason=disabled")
            #endif
            return
        }

        discardExpiredBatchIfNeeded()
        pruneNotifiedIDs()

        let alreadyPendingIDs = Set(pending.map(\.id))
        let newAchievements = achievements.filter {
            !wasNotified($0.id) && !alreadyPendingIDs.contains($0.id)
        }

        guard !newAchievements.isEmpty else {
            #if DEBUG
            print("[AchievementNotification] skipped reason=already_notified")
            #endif
            return
        }

        pending.append(contentsOf: newAchievements)
        if batchStartedAt == nil {
            batchStartedAt = .now
            startBatchExpiryTask()
        }

        #if DEBUG
        print("[AchievementNotification] queued count=\(newAchievements.count)")
        #endif

        await schedulePendingBatch()
    }

    private func schedulePendingBatch() async {
        guard
            isAchievementNotificationsEnabled,
            let batchStartedAt,
            !pending.isEmpty
        else { return }

        let elapsed = Date().timeIntervalSince(batchStartedAt)
        let remaining = max(1, aggregationWindow - elapsed)
        let notification = AppNotification.achievement(
            achievements: pending,
            after: remaining
        )
        let scheduled = await notificationManager.schedule(notification)

        // Once iOS accepts the request, remember every item in this batch so
        // another refresh cannot create duplicate notifications for the day.
        guard scheduled else { return }
        pending.forEach { markAsNotified($0.id) }
    }

    private func discardExpiredBatchIfNeeded() {
        guard let batchStartedAt else { return }
        guard Date().timeIntervalSince(batchStartedAt) >= aggregationWindow else { return }
        clearBatch(cancelScheduledNotification: false)
    }

    private func startBatchExpiryTask() {
        batchExpiryTask?.cancel()
        batchExpiryTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(self?.aggregationWindow ?? 0))
            } catch {
                return
            }
            self?.expireBatch()
        }
    }

    private func expireBatch() {
        clearBatch(cancelScheduledNotification: false)
    }

    private func clearBatch(cancelScheduledNotification: Bool) {
        batchExpiryTask?.cancel()
        batchExpiryTask = nil
        pending.removeAll()
        batchStartedAt = nil
        if cancelScheduledNotification {
            notificationManager.cancel(identifiers: [AppNotification.achievementBatchIdentifier])
        }
    }

    private func wasNotified(_ achievementID: String) -> Bool {
        notifiedAchievementIDs.contains(achievementID)
    }

    private func markAsNotified(_ achievementID: String) {
        var ids = notifiedAchievementIDs
        ids.insert(achievementID)
        defaults.set(Array(ids), forKey: Key.notifiedAchievements)
    }

    /// Removes stale ids of the form `prefix_YYYY-MM-DD` older than retentionDays.
    /// Non-dated ids (if any appear) are left untouched.
    private func pruneNotifiedIDs() {
        let ids = notifiedAchievementIDs
        guard !ids.isEmpty else { return }

        let cutoff = Achievement.dayFormatter.string(
            from: Calendar.current.date(
                byAdding: .day,
                value: -retentionDays,
                to: .now
            ) ?? .now
        )

        let pruned = ids.filter { id in
            guard let range = id.range(
                of: #"\d{4}-\d{2}-\d{2}$"#,
                options: .regularExpression
            ) else {
                return true
            }
            return String(id[range]) >= cutoff
        }

        if pruned.count != ids.count {
            defaults.set(Array(pruned), forKey: Key.notifiedAchievements)
        }
    }

    private var notifiedAchievementIDs: Set<String> {
        let values = defaults.array(
            forKey: Key.notifiedAchievements
        ) as? [String]
        ?? []
        return Set(values)
    }

    #if DEBUG
    func resetTestState() {
        clearSessionState()
        print("[AchievementNotification] test_state_reset")
    }
    #endif
}
