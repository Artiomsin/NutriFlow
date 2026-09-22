import SwiftUI

enum ActivityGlassPalette {
    static func cardBase(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light
            ? Color(red: 0.933, green: 0.945, blue: 0.961)
            : Color(red: 0.102, green: 0.118, blue: 0.149)
    }

    static func goalBase(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light
            ? Color(red: 0.898, green: 0.914, blue: 0.937)
            : Color(red: 0.137, green: 0.157, blue: 0.200)
    }

    static func border(for colorScheme: ColorScheme, isInset: Bool) -> Color {
        colorScheme == .light
            ? Color.black.opacity(isInset ? 0.08 : 0.10)
            : Color.white.opacity(isInset ? 0.12 : 0.14)
    }
}

struct ActivityGoalRow: View {
    let icon: String
    let label: String
    let current: Int
    let goal: Int
    let color: Color
    var unit: String = ""
    var displayCurrent: String? = nil
    var displayGoal: String? = nil
    var completionColor: Color? = nil
    var isEmbedded: Bool = false

    @Environment(\.glassEffectsMode) private var glassEffectsMode
    @Environment(\.colorScheme) private var colorScheme

    private var isLight: Bool {
        colorScheme == .light
    }

    private var pct: Double {
        guard goal > 0 else { return 0 }
        return min(Double(current) / Double(goal), 1.0)
    }

    private var currentText: String {
        displayCurrent
            ?? NumberFormatter.groupingFormatter.string(
                from: NSNumber(value: current)
            )
            ?? "\(current)"
    }

    private var goalText: String {
        displayGoal
            ?? NumberFormatter.groupingFormatter.string(
                from: NSNumber(value: goal)
            )
            ?? "\(goal)"
    }

    private var progressColor: Color {
        pct >= 1.0
            ? (completionColor ?? color)
            : color
    }

    private var iconColor: Color {
        pct >= 1.0 ? .white : color
    }

    var body: some View {
        HStack(spacing: 10) {
            progressColumn

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)

                Text(
                    "\(currentText) / \(goalText)" +
                    (unit.isEmpty ? "" : " \(unit)")
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

                Text("\(Int(pct * 100))%")
                    .font(
                        .system(
                            size: 24,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: pct >= 1.0
                                ? [
                                    progressColor,
                                    progressColor.opacity(0.72)
                                ]
                                : [
                                    color,
                                    color.opacity(0.60)
                                ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 17,
                    style: .continuous
                )
                .fill(
                    glassEffectsMode == .subtle
                        ? AnyShapeStyle(
                            ActivityGlassPalette.goalBase(for: colorScheme)
                                .opacity(colorScheme == .light ? 0.74 : 0.78)
                        )
                        : AnyShapeStyle(
                            LinearGradient(
                                colors: isLight
                                    ? [
                                        AppColors.surfaceSecondary,
                                        Color.black.opacity(0.025)
                                    ]
                                    : [
                                        Color.white.opacity(0.07),
                                        Color.white.opacity(0.035)
                                    ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 17,
                    style: .continuous
                )
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
            .stroke(
                glassEffectsMode == .subtle
                    ? ActivityGlassPalette.border(
                        for: colorScheme,
                        isInset: true
                    )
                    : .clear,
                lineWidth: 0.8
            )
        }

        .shadow(
            color: glassEffectsMode == .subtle
                ? Color.black.opacity(
                    isLight
                        ? (isEmbedded ? 0.025 : 0.045)
                        : (isEmbedded ? 0.10 : 0.16)
                )
                : Color.black.opacity(isLight ? 0.025 : 0.07),
            radius: glassEffectsMode == .subtle
                ? (
                    isLight
                        ? (isEmbedded ? 6 : 10)
                        : (isEmbedded ? 8 : 14)
                )
                : 8,
            x: 0,
            y: glassEffectsMode == .subtle
                ? (isEmbedded ? 2 : (isLight ? 3 : 5))
                : 3
        )
    }

    private var progressColumn: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(
                cornerRadius: 15,
                style: .continuous
            )
            .fill(
                Color.black.opacity(isLight ? 0.055 : 0.14)
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 15,
                    style: .continuous
                )
                .strokeBorder(
                    pct >= 1.0
                        ? (isLight
                            ? Color.black.opacity(0.24)
                            : Color.white.opacity(0.56))
                        : (isLight
                            ? AppColors.border.opacity(0.95)
                            : Color.white.opacity(0.28)),
                    lineWidth: pct >= 1.0 ? 1.8 : 1.2
                )
            }

            let fillHeight = max(70 * pct, 12)
            let fillRadius = min(15, fillHeight / 2)

            if pct >= 1.0 {
                ZStack {
                    RoundedRectangle(
                        cornerRadius: 15,
                        style: .continuous
                    )
                    .fill(progressColor)

                    LinearGradient(
                        colors: [
                            Color.white.opacity(isLight ? 0.24 : 0.16),
                            .clear,
                            Color.black.opacity(isLight ? 0.18 : 0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    RadialGradient(
                        colors: [
                            Color.white.opacity(isLight ? 0.22 : 0.14),
                            .clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 38
                    )

                    RadialGradient(
                        colors: [
                            Color.black.opacity(isLight ? 0.14 : 0.22),
                            .clear
                        ],
                        center: .bottomTrailing,
                        startRadius: 0,
                        endRadius: 48
                    )
                }
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 15,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 15,
                        style: .continuous
                    )
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isLight ? 0.36 : 0.24),
                                progressColor.opacity(0.92),
                                Color.black.opacity(isLight ? 0.22 : 0.34)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.35
                    )
                }
                .shadow(
                    color: progressColor.opacity(0.26),
                    radius: 7,
                    y: 3
                )
            } else {
                RoundedRectangle(
                    cornerRadius: fillRadius,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.45),
                            color.opacity(0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: fillHeight)
                .mask {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0),
                            Color.black
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .overlay {
                    RoundedRectangle(
                        cornerRadius: fillRadius,
                        style: .continuous
                    )
                    .strokeBorder(
                        color.opacity(0.78),
                        lineWidth: 1
                    )
                }
                .shadow(
                    color: color.opacity(0.20),
                    radius: 5,
                    y: 3
                )
            }

            Image(systemName: icon)
                .font(
                    .system(
                        size: 17,
                        weight: .semibold
                    )
                )
                .foregroundStyle(iconColor)
                .shadow(
                    color: isLight
                        ? Color.white.opacity(0.18)
                        : color.opacity(0.40),
                    radius: isLight ? 2 : 6
                )
                .padding(.bottom, 7)
        }
        .frame(width: 46, height: 70)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 15,
                style: .continuous
            )
        )
        .shadow(
            color: isLight
                ? Color.black.opacity(0.04)
                : color.opacity(0.18),
            radius: isLight ? 6 : 10,
            y: 4
        )
    }
}

private extension NumberFormatter {
    static let groupingFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

#Preview("Activity Goal Row — Glass") {
    VStack(spacing: 24) {
        ActivityGoalRow(
            icon: "figure.walk",
            label: "Steps",
            current: 9000,
            goal: 10000,
            color: .green,
            unit: "steps"
        )

        ActivityGoalRow(
            icon: "flame.fill",
            label: "Active kcal",
            current: 400,
            goal: 400,
            color: .orange,
            unit: "kcal"
        )

        ActivityGoalRow(
            icon: "figure.run",
            label: "Running",
            current: 2500,
            goal: 10000,
            color: .green,
            unit: "steps"
        )
    }
    .padding(.horizontal, AppSpacing.paddingHorizontal)
    .padding(.vertical, 20)
    .background(AppColors.background)
    .environment(\.glassEffectsMode, .off)
}
