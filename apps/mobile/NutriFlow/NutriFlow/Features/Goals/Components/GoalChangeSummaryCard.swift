import SwiftUI

/// Read-only summary of the values recalculated for a saved plan.
/// It deliberately has no actions: automatic goals are applied immediately.
struct GoalChangeSummaryCard: View {
    /// Raw values are kept so the card can re-format them when the person
    /// switches units while this result screen is still open.
    enum Value: Equatable {
        case metric(String, Double?)
        case bodyWeight(Double?)
        case weeklyRate(Double?)
        case date(String?)
        case text(String)
    }

    struct Change: Identifiable, Equatable {
        let id: String
        let label: String
        let from: Value
        let to: Value
    }

    let changes: [Change]

    @State private var prefsStore = PreferencesStore.shared

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

                            Text(text(change.from))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppColors.textTertiary)
                                .strikethrough()

                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(AppColors.textSecondary)

                            Text(text(change.to))
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

    static func metricChanges(_ changes: [GoalMetricChange]) -> [Change] {
        changes.compactMap { change in
            guard let key = GoalMetricKey(rawValue: change.metric) else { return nil }
            return Change(
                id: "metric.\(change.id)",
                label: label(for: key),
                from: .metric(key.rawValue, change.from),
                to: .metric(key.rawValue, change.to)
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

    private func text(_ value: Value) -> String {
        let preferredUnits = prefsStore.preferredUnits

        switch value {
        case .metric(let metric, let number):
            guard let number else { return "Not set" }
            return GoalHistoryFormat.value(
                metric,
                number,
                preferredUnits: preferredUnits
            )
        case .bodyWeight(let kg):
            guard let kg else { return "Not set" }
            let amount = UnitConversion.formatBodyWeight(
                kg: kg,
                preferred: preferredUnits
            )
            let unit = UnitConversion.bodyWeightUnitLabel(preferred: preferredUnits)
            return "\(amount) \(unit)"
        case .weeklyRate(let kgPerWeek):
            guard let kgPerWeek else { return "Not set" }
            let amount = UnitConversion.bodyWeightToDisplay(
                kg: kgPerWeek,
                preferred: preferredUnits
            )
            let text = amount.formatted(.number.precision(.fractionLength(0...2)))
            let unit = UnitConversion.bodyWeightUnitLabel(preferred: preferredUnits)
            return "\(text) \(unit)/week"
        case .date(let date):
            guard let date, !date.isEmpty else { return "Not set" }
            guard let parsed = AppDate.dateOnlyFormatter().date(from: date) else {
                return date
            }
            return AppDate.displayFormatter("d MMM yyyy").string(from: parsed)
        case .text(let text):
            text
        }
    }
}
