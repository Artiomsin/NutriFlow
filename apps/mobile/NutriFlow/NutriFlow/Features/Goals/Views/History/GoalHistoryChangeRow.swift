import SwiftUI


struct GoalHistoryChangeRow: View {
    let change: GoalMetricChange
    let preferredUnits: PreferredUnits

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(GoalHistoryFormat.metricLabel(change.metric))
                .font(.footnote)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text(
                "\(GoalHistoryFormat.value(change.metric, change.from, preferredUnits: preferredUnits)) → \(GoalHistoryFormat.value(change.metric, change.to, preferredUnits: preferredUnits))"
            )
            .font(.footnote.monospacedDigit())
            .foregroundColor(AppColors.textSecondary)
        }
    }
}
