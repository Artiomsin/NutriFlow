import SwiftUI

/// A single row in the expanded history card. Plan rows and daily-goal rows
/// share the same layout but use different formatters.
enum GoalHistoryDisplayRow: Identifiable {
    case metric(GoalMetricChange)
    case plan(GoalPlanChange)

    var id: String {
        switch self {
        case .metric(let change): "metric.\(change.metric)"
        case .plan(let change): "plan.\(change.metric)"
        }
    }

    var metric: String {
        switch self {
        case .metric(let change): change.metric
        case .plan(let change): change.metric
        }
    }

    var from: GoalHistoryValue {
        switch self {
        case .metric(let change):
            change.from.map(GoalHistoryValue.number) ?? .none
        case .plan(let change):
            change.from
        }
    }

    var to: GoalHistoryValue {
        switch self {
        case .metric(let change):
            change.to.map(GoalHistoryValue.number) ?? .none
        case .plan(let change):
            change.to
        }
    }
}

struct GoalHistoryChangeRow: View {
    let row: GoalHistoryDisplayRow
    let preferredUnits: PreferredUnits

    private var label: String {
        switch row {
        case .metric(let change): GoalHistoryFormat.metricLabel(change.metric)
        case .plan(let change): GoalHistoryFormat.planLabel(change.metric)
        }
    }

    private var fromText: String {
        format(row.from)
    }

    private var toText: String {
        format(row.to)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.footnote)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text("\(fromText) → \(toText)")
                .font(.footnote.monospacedDigit())
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private func format(_ value: GoalHistoryValue) -> String {
        switch row {
        case .metric:
            switch value {
            case .number(let number):
                GoalHistoryFormat.value(
                    row.metric,
                    number,
                    preferredUnits: preferredUnits
                )
            case .text(let text):
                text
            case .none:
                "—"
            }
        case .plan:
            GoalHistoryFormat.planValue(
                row.metric,
                value,
                preferredUnits: preferredUnits
            )
        }
    }
}
