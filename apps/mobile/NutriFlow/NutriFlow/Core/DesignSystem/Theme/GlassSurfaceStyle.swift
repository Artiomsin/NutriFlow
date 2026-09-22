import SwiftUI

enum GlassSurfaceLevel {
    case raised
    case inset
}

extension View {
    func appGlassSurface(
        cornerRadius: CGFloat = AppRadius.medium,
        level: GlassSurfaceLevel = .raised
    ) -> some View {
        modifier(
            AppGlassSurfaceModifier(
                cornerRadius: cornerRadius,
                level: level
            )
        )
    }
}

private struct AppGlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let level: GlassSurfaceLevel

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.glassEffectsMode) private var glassEffectsMode

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var glassOpacity: Double {
        switch (colorScheme, level) {
        case (.light, .raised):
            0.80
        case (.light, .inset):
            0.87
        case (.dark, .raised):
            0.74
        case (.dark, .inset):
            0.82
        @unknown default:
            0.72
        }
    }

    private var borderOpacity: Double {
        switch (colorScheme, level) {
        case (.light, .raised):
            0.62
        case (.light, .inset):
            0.46
        case (.dark, .raised):
            0.70
        case (.dark, .inset):
            0.50
        @unknown default:
            0.70
        }
    }

    private var diffusionStrength: Double {
        level == .raised ? 1 : 0.42
    }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    shape.fill(
                        glassEffectsMode == .subtle
                            ? AppColors.glassSurface.opacity(glassOpacity)
                            : AppColors.surface
                    )

                    if glassEffectsMode == .subtle {
                        LinearGradient(
                            colors: [
                                Color.black.opacity(
                                    (colorScheme == .light ? 0.015 : 0.12)
                                        * diffusionStrength
                                ),
                                Color(
                                    red: 0.20,
                                    green: 0.08,
                                    blue: 0.34
                                )
                                .opacity(
                                    (colorScheme == .light ? 0.018 : 0.09)
                                        * diffusionStrength
                                ),
                                Color(
                                    red: 0.07,
                                    green: 0.11,
                                    blue: 0.30
                                )
                                .opacity(
                                    (colorScheme == .light ? 0.010 : 0.06)
                                        * diffusionStrength
                                ),
                                Color.black.opacity(
                                    (colorScheme == .light ? 0.035 : 0.22)
                                        * diffusionStrength
                                )
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        RadialGradient(
                            colors: [
                                Color.black.opacity(
                                    (colorScheme == .light ? 0.04 : 0.26)
                                        * diffusionStrength
                                ),
                                .clear
                            ],
                            center: .bottomTrailing,
                            startRadius: 0,
                            endRadius: 260
                        )

                        RadialGradient(
                            colors: [
                                Color(
                                    red: 0.43,
                                    green: 0.16,
                                    blue: 0.68
                                )
                                .opacity(
                                    (colorScheme == .light ? 0.014 : 0.09)
                                        * diffusionStrength
                                ),
                                .clear
                            ],
                            center: .bottomLeading,
                            startRadius: 0,
                            endRadius: 180
                        )

                        RadialGradient(
                            colors: [
                                Color(
                                    red: 0.14,
                                    green: 0.18,
                                    blue: 0.48
                                )
                                .opacity(
                                    (colorScheme == .light ? 0.010 : 0.06)
                                        * diffusionStrength
                                ),
                                .clear
                            ],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: 170
                        )
                    }
                }
                .clipShape(shape)
            }
            .overlay {
                shape.stroke(
                    glassEffectsMode == .subtle
                        ? AppColors.glassBorder.opacity(borderOpacity)
                        : .clear,
                    lineWidth: glassEffectsMode == .subtle ? 0.8 : 0
                )
            }
            .shadow(
                color: glassEffectsMode == .subtle
                    ? Color.black.opacity(colorScheme == .light ? 0.035 : 0.12)
                    : .clear,
                radius: level == .raised
                    ? (colorScheme == .light ? 7 : 8)
                    : 4,
                y: level == .raised ? 3 : 2
            )
    }
}
