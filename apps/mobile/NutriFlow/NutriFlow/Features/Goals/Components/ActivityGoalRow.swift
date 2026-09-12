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

    private var pct: Double {
        guard goal > 0 else { return 0 }
        return min(Double(current) / Double(goal), 1.0)
    }

    private var currentText: String {
        displayCurrent ?? NumberFormatter.groupingFormatter.string(from: NSNumber(value: current)) ?? "\(current)"
    }

    private var goalText: String {
        displayGoal ?? NumberFormatter.groupingFormatter.string(from: NSNumber(value: goal)) ?? "\(goal)"
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 15)
                    .fill(.thinMaterial)

                let fillHeight = max(70 * pct, 12)
                let fillRadius = min(15, fillHeight / 2)

                RoundedRectangle(cornerRadius: fillRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                pct >= 1.0
                                    ? (completionColor ?? color).opacity(0.45)
                                    : color.opacity(0.45),
                                pct >= 1.0
                                    ? (completionColor ?? color).opacity(0.6)
                                    : color.opacity(0.95),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: fillHeight)
                    .mask(
                        LinearGradient(
                            colors: [.black.opacity(0), .black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: fillRadius)
                            .stroke(color.opacity(0.85), lineWidth: 1.2)
                    )
                    .shadow(color: color.opacity(0.5), radius: 5)

                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: color, radius: 7)
                    .padding(.bottom, 7)
            }
            .frame(width: 46, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: color.opacity(0.35), radius: 11, y: 5)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(AppTheme.textSecondary)
                Text("\(currentText) / \(goalText)\(unit.isEmpty ? "" : " \(unit)")")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Text("\(Int(pct * 100))%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: pct >= 1.0
                                ? [completionColor ?? color, (completionColor ?? color).opacity(0.6)]
                                : [color, color.opacity(0.6)],
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
                .fill(hasGlass ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(AppTheme.cardBackground))
        }
        .background {
            if hasGlass {
                RoundedRectangle(cornerRadius: 17)
                    .fill(.thinMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
            }
        }
        .overlay {
            if hasGlass {
                RoundedRectangle(cornerRadius: 17)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.14), .white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.plusLighter)
            }
        }
        .overlay {
            if hasGlass {
                RoundedRectangle(cornerRadius: 17)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
        }
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

#Preview("Liquid") {
    VStack(spacing: 24) {
        ActivityGoalRow(
            icon: "figure.walk",
            label: "Steps",
            current: 5000,
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
    .padding(.horizontal, AppTheme.paddingHorizontal)
    .padding(.vertical, 20)
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}
