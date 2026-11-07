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

    var hasCompletedInitialBackfill: Bool = false {
        didSet {
            saveHasCompletedInitialBackfill()
        }
    }

    private let defaults = UserDefaults.standard
    private let unitsKey = "preferred_units"
    private let timeZoneKey = "user_time_zone"
    private let autoUpdateTimeZoneKey = "user_auto_update_time_zone"
    private let initialBackfillKey = "user_initial_backfill_completed"

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

    private func saveHasCompletedInitialBackfill() {
        defaults.set(hasCompletedInitialBackfill, forKey: initialBackfillKey)
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
        hasCompletedInitialBackfill = defaults.bool(forKey: initialBackfillKey)
    }
}
