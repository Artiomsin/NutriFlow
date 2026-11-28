import SwiftUI

/// Read-only summary of the values recalculated for a saved plan.
/// It deliberately has no actions: automatic goals are applied immediately.
struct GoalChangeSummaryCard: View {
    struct Change: Identifiable, Equatable {
        let id: String
        let label: String
        let from: String
        let to: String
    }

    let changes: [Change]

    @ViewBuilder
    var body: some View {
        if !changes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Updated automatically", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(changes) { change in
                        HStack(spacing: 10) {
                            Text(change.label)
                                .font(.footnote)
                                .foregroundStyle(AppColors.textSecondary)

                            Spacer(minLength: 8)

                            Text(change.from)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppColors.textTertiary)
                                .strikethrough()

                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(AppColors.textSecondary)

                            Text(change.to)
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(AppColors.textPrimary)
                        }
                    }
                }
                .padding(12)
                .appGlassSurface(level: .inset)

                Text("Recalculated from your updated plan.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .appGlassSurface()
        }
    }

    static func metricChanges(
        _ changes: [GoalMetricChange],
        preferredUnits: PreferredUnits
    ) -> [Change] {
        changes.compactMap { change in
            guard let key = GoalMetricKey(rawValue: change.metric) else { return nil }
            return Change(
                id: "metric.\(change.id)",
                label: label(for: key),
                from: format(change.from, key: key, preferredUnits: preferredUnits),
                to: format(change.to, key: key, preferredUnits: preferredUnits)
            )
        }
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

    private static func format(
        _ value: Double?,
        key: GoalMetricKey,
        preferredUnits: PreferredUnits
    ) -> String {
        guard let value else { return "Not set" }

        switch key {
        case .dailyCaloriesGoal, .dailyActiveCaloriesGoal:
            return UnitConversion.formatEnergy(kcal: Int(value.rounded()), preferred: preferredUnits)
        case .dailyProteinGoal, .dailyFatGoal, .dailyCarbsGoal:
            return "\(value.formatted(.number.precision(.fractionLength(1)))) g"
        case .dailyWaterGoal:
            return "\(Int(value.rounded())) ml"
        case .dailyStepsGoal, .weeklyWorkoutsGoal, .weeklyWorkoutMinutesGoal,
             .nightlySleepMinMinutes, .nightlySleepMaxMinutes:
            return "\(Int(value.rounded()))"
        }
    }
}
