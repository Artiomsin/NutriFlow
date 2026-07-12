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

    private let defaults = UserDefaults.standard
    private let key = "preferred_units"

    private init() {
        load()
    }

    func updateFromProfile(_ profile: UserProfile) {
        if let units = profile.preferredUnits {
            preferredUnits = units
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(preferredUnits) {
            defaults.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let units = try? JSONDecoder().decode(PreferredUnits.self, from: data) else { return }
        preferredUnits = units
    }
}
