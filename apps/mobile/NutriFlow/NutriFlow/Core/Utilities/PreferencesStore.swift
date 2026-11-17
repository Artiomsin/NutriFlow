import Foundation
import Observation

@Observable
final class PreferencesStore {
    static let shared = PreferencesStore()

    var preferredUnits: PreferredUnits = .default {
        didSet {
            save()
        }
    }

    var timeZone: String = TimeZone.current.identifier {
        didSet {
            saveTimeZone()
        }
    }

    var autoUpdateTimeZone: Bool = false {
        didSet {
            saveAutoUpdateTimeZone()
        }
    }

    var hasCompletedActivityBackfill: Bool = false {
        didSet {
            defaults.set(hasCompletedActivityBackfill, forKey: activityBackfillKey)
        }
    }

    var hasCompletedSleepBackfill: Bool = false {
        didSet {
            defaults.set(hasCompletedSleepBackfill, forKey: sleepBackfillKey)
        }
    }

    private let defaults = UserDefaults.standard
    private let unitsKey = "preferred_units"
    private let timeZoneKey = "user_time_zone"
    private let autoUpdateTimeZoneKey = "user_auto_update_time_zone"
    private let activityBackfillKey = "user_activity_backfill_completed"
    private let sleepBackfillKey = "user_sleep_backfill_completed"
    private let legacyInitialBackfillKey = "user_initial_backfill_completed"

    private init() {
        load()
    }

    func updateFromProfile(_ profile: UserProfile) {
        if let units = profile.preferredUnits {
            preferredUnits = units
        }
        if let timeZone = profile.timeZone, !timeZone.isEmpty {
            self.timeZone = timeZone
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(preferredUnits) {
            defaults.set(data, forKey: unitsKey)
        }
    }

    private func saveTimeZone() {
        defaults.set(timeZone, forKey: timeZoneKey)
    }

    private func saveAutoUpdateTimeZone() {
        defaults.set(autoUpdateTimeZone, forKey: autoUpdateTimeZoneKey)
    }

    /// Backfill state belongs to the signed-in account and must be cleared on
    /// logout, otherwise the next account inherits a partial backfill.
    func resetSessionSyncState() {
        hasCompletedActivityBackfill = false
        hasCompletedSleepBackfill = false
        defaults.removeObject(forKey: legacyInitialBackfillKey)
    }

    private func load() {
        if let data = defaults.data(forKey: unitsKey),
           let units = try? JSONDecoder().decode(PreferredUnits.self, from: data) {
            preferredUnits = units
        }
        if let savedTimeZone = defaults.string(forKey: timeZoneKey), !savedTimeZone.isEmpty {
            timeZone = savedTimeZone
        }
        autoUpdateTimeZone = defaults.bool(forKey: autoUpdateTimeZoneKey)

        // Migrate the old shared flag once: an existing account has already
        // done its backfill, so it must not repeat it, and a new account starts
        // with both flags off after logout.
        let legacyCompleted = defaults.bool(forKey: legacyInitialBackfillKey)
        let activityCompleted = defaults.bool(forKey: activityBackfillKey) || legacyCompleted
        let sleepCompleted = defaults.bool(forKey: sleepBackfillKey) || legacyCompleted
        hasCompletedActivityBackfill = activityCompleted
        hasCompletedSleepBackfill = sleepCompleted
        if legacyCompleted {
            defaults.set(true, forKey: activityBackfillKey)
            defaults.set(true, forKey: sleepBackfillKey)
            defaults.removeObject(forKey: legacyInitialBackfillKey)
        }
    }
}
