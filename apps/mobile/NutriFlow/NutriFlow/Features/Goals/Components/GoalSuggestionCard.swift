import SwiftUI

/// Shows the recalculated goals the API keeps while manual mode stays active.
/// Applying the suggestion keeps manual mode; it only updates the values that
/// were recalculated for the current plan.
struct GoalSuggestionCard: View {
    let suggestion: GoalSuggestion
    let isProcessing: Bool
    let onApply: () -> Void
    let onKeep: () -> Void

    @State private var prefsStore = PreferencesStore.shared

    private var rows: [Row] {
        suggestion.diff.compactMap { change in
            guard let key = GoalMetricKey(rawValue: change.metric) else { return nil }
            let prefs = prefsStore.preferredUnits
            return Row(
                id: change.id,
                label: Self.label(for: key),
                color: Self.color(for: key),
                from: Self.format(change.from, key: key, prefs: prefs),
                to: Self.format(change.to, key: key, prefs: prefs)
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if rows.isEmpty {
                Text("No goal values would change. You can keep your current goals.")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                changes
            }

            Text("Your manual mode stays on. Only the values listed above will change; your other targets stay as you set them.")
                .font(.caption)
                .foregroundStyle(AppColors.textTertiary)

            buttons
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlassSurface()
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColors.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Recalculated for your plan")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Text("Apply these values without leaving manual mode")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private var changes: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows) { row in
                HStack(spacing: 10) {
                    Circle()
                        .fill(row.color)
                        .frame(width: 8, height: 8)

                    Text(row.label)
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)

                    Spacer(minLength: 8)

                    Text(row.from)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColors.textTertiary)
                        .strikethrough()

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)

                    Text(row.to)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
        }
        .padding(12)
        .appGlassSurface(level: .inset)
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button {
                onApply()
            } label: {
                Text("Apply values")
                    .font(.headline)
                    .foregroundStyle(AppColors.accentOnPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            }

            Button {
                onKeep()
            } label: {
                Text("Keep current goals")
                    .font(.headline)
                    .foregroundStyle(AppColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .appGlassSurface(level: .inset)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(AppColors.accent, lineWidth: 1.5)
                    )
            }
        }
        .disabled(isProcessing)
        .opacity(isProcessing ? 0.6 : 1)
    }

    private struct Row: Identifiable {
        let id: String
        let label: String
        let color: Color
        let from: String
        let to: String
    }

    private static func label(for key: GoalMetricKey) -> String {
        switch key {
        case .dailyCaloriesGoal: "Calories"
        case .dailyProteinGoal: "Protein"
        case .dailyFatGoal: "Fat"
        case .dailyCarbsGoal: "Carbs"
        case .dailyWaterGoal: "Water"
        case .dailyStepsGoal: "Steps"
        case .dailyActiveCaloriesGoal: "Active calories"
        case .weeklyWorkoutsGoal: "Workouts / week"
        case .weeklyWorkoutMinutesGoal: "Workout minutes / week"
        case .nightlySleepMinMinutes: "Min sleep"
        case .nightlySleepMaxMinutes: "Max sleep"
        }
    }

    private static func color(for key: GoalMetricKey) -> Color {
        switch key {
        case .dailyCaloriesGoal, .dailyActiveCaloriesGoal: .orange
        case .dailyProteinGoal: .yellow
        case .dailyFatGoal: .purple
        case .dailyCarbsGoal: .blue
        case .dailyWaterGoal: .cyan
        case .dailyStepsGoal: .green
        case .weeklyWorkoutsGoal: .pink
        case .weeklyWorkoutMinutesGoal, .nightlySleepMinMinutes, .nightlySleepMaxMinutes: .indigo
        }
    }

    private static func format(
        _ value: Double?,
        key: GoalMetricKey,
        prefs: PreferredUnits
    ) -> String {
        guard let value else { return "Not set" }

        switch key {
        case .dailyCaloriesGoal, .dailyActiveCaloriesGoal:
            return UnitConversion.formatEnergy(kcal: Int(value.rounded()), preferred: prefs)
        case .dailyProteinGoal, .dailyFatGoal, .dailyCarbsGoal:
            return "\(value.formatted(.number.precision(.fractionLength(0...1)))) g"
        case .dailyWaterGoal:
            return "\(Int(value.rounded())) ml"
        case .dailyStepsGoal, .weeklyWorkoutsGoal, .weeklyWorkoutMinutesGoal,
             .nightlySleepMinMinutes, .nightlySleepMaxMinutes:
            return "\(Int(value.rounded()))"
        }
    }
}
