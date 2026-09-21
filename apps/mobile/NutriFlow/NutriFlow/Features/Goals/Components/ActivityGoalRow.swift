import SwiftUI

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
    var hasGlass: Bool = true

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
        if pct >= 1.0 {
            return .white
        }
        return color
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
            RoundedRectangle(cornerRadius: 17)
                .fill(
                    hasGlass
                        ? AnyShapeStyle(.regularMaterial)
                        : AnyShapeStyle(AppColors.surface)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 17)
                .stroke(
                    hasGlass
                        ? (
                            isLight
                                ? Color.black.opacity(0.055)
                                : Color.white.opacity(0.10)
                        )
                        : .clear,
                    lineWidth: 1
                )
        }
        .shadow(
            color: hasGlass
                ? (
                    isLight
                        ? Color.black.opacity(0.045)
                        : Color.black.opacity(0.20)
                )
                : Color.black.opacity(
                    isLight ? 0.025 : 0.07
                ),
            radius: hasGlass
                ? (isLight ? 11 : 17)
                : 8,
            x: 0,
            y: hasGlass
                ? (isLight ? 3 : 7)
                : 3
        )
    }

    private var progressColumn: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 15)
                .fill(
                    isLight
                        ? AppColors.surfaceSecondary
                        : Color.white.opacity(0.07)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(
                            isLight
                                ? AppColors.border.opacity(0.8)
                                : Color.white.opacity(0.12),
                            lineWidth: 1
                        )
                }

            let fillHeight = max(70 * pct, 12)
            let fillRadius = min(15, fillHeight / 2)

            if pct >= 1.0 {
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        LinearGradient(
                            colors: [
                                progressColor,
                                progressColor.opacity(0.88)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(
                                progressColor.opacity(0.90),
                                lineWidth: 1.2
                            )
                    }
                    .shadow(
                        color: progressColor.opacity(0.25),
                        radius: 7,
                        y: 3
                    )
            } else {
                RoundedRectangle(cornerRadius: fillRadius)
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
                        RoundedRectangle(cornerRadius: fillRadius)
                            .stroke(
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
            RoundedRectangle(cornerRadius: 15)
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

#Preview("Activity Goal Row") {
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
            label: "No glass",
            current: 2500,
            goal: 10000,
            color: .green,
            unit: "steps",
            hasGlass: false
        )

        ActivityGoalRow(
            icon: "figure.walk",
            label: "Steps (low)",
            current: 1200,
            goal: 10000,
            color: .green,
            unit: "steps"
        )
    }
    .padding(.horizontal, AppSpacing.paddingHorizontal)
    .padding(.vertical, 20)
    .background(AppColors.background)
}
