import SwiftUI

enum GlassSurfaceLevel {
    /// Standard information card.
    case raised
    /// A primary card that should stand forward from the surrounding content.
    case prominent
    /// A quiet surface nested inside another card.
    case inset
    /// A compact surface that represents a tappable row or control.
    case interactive
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
            0.74
        case (.light, .prominent):
            0.58
        case (.light, .inset):
            0.92
        case (.light, .interactive):
            0.84
        case (.dark, .raised):
            0.78
        case (.dark, .prominent):
            0.62
        case (.dark, .inset):
            0.90
        case (.dark, .interactive):
            0.84
        @unknown default:
            0.72
        }
    }

    private var borderOpacity: Double {
        switch (colorScheme, level) {
        case (.light, .raised):
            0.62
        case (.light, .prominent):
            0.84
        case (.light, .inset):
            0.28
        case (.light, .interactive):
            0.82
        case (.dark, .raised):
            0.70
        case (.dark, .prominent):
            0.88
        case (.dark, .inset):
            0.30
        case (.dark, .interactive):
            0.84
        @unknown default:
            0.70
        }
    }

    private var diffusionStrength: Double {
        switch level {
        case .raised:
            0.94
        case .prominent:
            1.46
        case .inset:
            0.12
        case .interactive:
            0.44
        }
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
                        shape.fill(
                            Color.black.opacity(
                                colorScheme == .light ? 0.025 : coreDarkening
                            )
                        )

                        LinearGradient(
                            colors: [
                                Color.black.opacity(
                                    (colorScheme == .light ? 0.025 : 0.16)
                                        * diffusionStrength
                                ),
                                .clear,
                                Color.black.opacity(
                                    (colorScheme == .light ? 0.06 : 0.30)
                                        * diffusionStrength
                                )
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        RadialGradient(
                            colors: [
                                .clear,
                                Color.black.opacity(
                                    (colorScheme == .light ? 0.025 : 0.22)
                                        * diffusionStrength
                                )
                            ],
                            center: .center,
                            startRadius: 60,
                            endRadius: 340
                        )

                        RadialGradient(
                            colors: [
                                Color.black.opacity(
                                    (colorScheme == .light ? 0.04 : 0.36)
                                        * diffusionStrength
                                ),
                                .clear
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 240
                        )

                        RadialGradient(
                            colors: [
                                Color.black.opacity(
                                    (colorScheme == .light ? 0.07 : 0.48)
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
                                    red: 0.25,
                                    green: 0.08,
                                    blue: 0.90
                                )
                                .opacity(
                                    (colorScheme == .light ? 0.012 : 0.13)
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
                                    red: 0.015,
                                    green: 0.09,
                                    blue: 0.62
                                )
                                .opacity(
                                    (colorScheme == .light ? 0.010 : 0.13)
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
                    ? Color.black.opacity(shadowOpacity)
                    : .clear,
                radius: shadowRadius,
                y: shadowOffset
            )
    }

    private var shadowOpacity: Double {
        switch (colorScheme, level) {
        case (.light, .prominent): 0.16
        case (.dark, .prominent): 0.30
        case (.light, .interactive): 0.05
        case (.dark, .interactive): 0.11
        case (_, .inset): 0
        case (.light, .raised): 0.07
        case (.dark, .raised): 0.15
        @unknown default: 0.12
        }
    }

    private var coreDarkening: Double {
        switch level {
        case .prominent: 0.30
        case .raised: 0.22
        case .interactive: 0.16
        case .inset: 0.06
        }
    }

    private var shadowRadius: CGFloat {
        switch (colorScheme, level) {
        case (.light, .prominent): 16
        case (.dark, .prominent): 20
        case (_, .raised): colorScheme == .light ? 8 : 10
        case (_, .interactive): colorScheme == .light ? 5 : 6
        case (_, .inset): 0
        @unknown default: 8
        }
    }

    private var shadowOffset: CGFloat {
        switch level {
        case .prominent: colorScheme == .light ? 7 : 10
        case .raised: colorScheme == .light ? 3 : 5
        case .interactive: 2
        case .inset: 0
        }
    }
}
