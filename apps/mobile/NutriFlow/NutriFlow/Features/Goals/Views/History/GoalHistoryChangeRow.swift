import SwiftUI

/// Одна строка изменения показателя цели: метрика, старое значение → новое.
struct GoalHistoryChangeRow: View {
    let change: GoalMetricChange

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(GoalHistoryFormat.metricLabel(change.metric))
                .font(.footnote)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text(
                "\(GoalHistoryFormat.value(change.metric, change.from)) → \(GoalHistoryFormat.value(change.metric, change.to))"
            )
            .font(.footnote.monospacedDigit())
            .foregroundColor(AppColors.textSecondary)
        }
    }
}
