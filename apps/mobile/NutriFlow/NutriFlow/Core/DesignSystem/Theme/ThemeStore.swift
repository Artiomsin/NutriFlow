import Foundation
import Observation

@MainActor
@Observable
final class ThemeStore {

    private let defaults: UserDefaults
    private let key = "theme_mode"

    var mode: ThemeMode {
        didSet {
            save()
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let raw = defaults.string(forKey: key),
           let savedMode = ThemeMode(rawValue: raw) {
            self.mode = savedMode
        } else {
            self.mode = .system
        }
    }

    private func save() {
        defaults.set(mode.rawValue, forKey: key)
    }
}
