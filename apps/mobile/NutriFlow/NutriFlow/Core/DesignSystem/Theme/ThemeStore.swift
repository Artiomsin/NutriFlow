import Foundation
import Observation

@MainActor
@Observable
final class ThemeStore {

    private let defaults: UserDefaults
    private let themeModeKey = "theme_mode"
    private let glassEffectsModeKey = "glass_effects_mode"

    var mode: ThemeMode {
        didSet {
            save()
        }
    }

    var glassEffectsMode: GlassEffectsMode {
        didSet {
            save()
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let raw = defaults.string(forKey: themeModeKey),
           let savedMode = ThemeMode(rawValue: raw) {
            self.mode = savedMode
        } else {
            self.mode = .system
        }

        if let raw = defaults.string(forKey: glassEffectsModeKey),
           let savedMode = GlassEffectsMode(rawValue: raw) {
            self.glassEffectsMode = savedMode
        } else {
            self.glassEffectsMode = .off
        }
    }

    private func save() {
        defaults.set(mode.rawValue, forKey: themeModeKey)
        defaults.set(glassEffectsMode.rawValue, forKey: glassEffectsModeKey)
    }
}
