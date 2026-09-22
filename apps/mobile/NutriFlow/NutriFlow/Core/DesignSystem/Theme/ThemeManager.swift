import SwiftUI

enum GlassEffectsMode: String, CaseIterable, Identifiable {
    case off
    case subtle

    var id: Self { self }

    var title: String {
        switch self {
        case .off:
            "Off"
        case .subtle:
            "On"
        }
    }
}

extension EnvironmentValues {
    @Entry var glassEffectsMode: GlassEffectsMode = .off
}

extension View {
    func glassEffectsMode(_ mode: GlassEffectsMode) -> some View {
        environment(\.glassEffectsMode, mode)
    }
}

enum ThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }

    var title: String {
        switch self {
        case .system:
            "System"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }
}
