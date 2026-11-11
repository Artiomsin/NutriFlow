import SwiftUI

struct GoalHistoryCard: View {
    let event: GoalHistoryEvent
    let dayStart: Date?
    let isLatest: Bool

    @Binding private var expanded: Set<String>

    init(
        event: GoalHistoryEvent,
        dayStart: Date? = nil,
        expanded: Binding<Set<String>>,
        isLatest: Bool = false
    ) {
        self.event = event
        self.dayStart = dayStart
        self._expanded = expanded
        self.isLatest = isLatest
    }

    var body: some View {
        let isExpanded = expanded.contains(event.id)
        let visible = isExpanded
            ? event.changes
            : Array(event.changes.prefix(3))

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(timeText(event))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                if isLatest {
                    Text("LATEST")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppColors.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppColors.accent.opacity(0.12))
                        .clipShape(Capsule())
                }

                if event.automaticCount > 1 {
                    Text("\(event.automaticCount) recalculations")
                        .font(.caption2)
                        .foregroundColor(AppColors.textTertiary)
                }

                Spacer()

                Text(GoalHistoryFormat.sourceLabel(event.source))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.accent)
            }

            if let reason = GoalHistoryFormat.reasonLabel(event.reason) {
                Text(reason)
                    .font(.caption2)
                    .foregroundColor(AppColors.textTertiary)
            }

            VStack(spacing: 6) {
                ForEach(visible) { change in
                    GoalHistoryChangeRow(change: change)
                }
            }

            if event.changes.count > 3 {
                Button {
                    if isExpanded {
                        expanded.remove(event.id)
                    } else {
                        expanded.insert(event.id)
                    }
                } label: {
                    Text(
                        isExpanded
                            ? "Show less"
                            : "And \(event.changes.count - 3) more"
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.paddingHorizontal)
        .padding(.vertical, 12)
        .appGlassSurface()
    }

    private func timeText(_ event: GoalHistoryEvent) -> String {
        if let dayStart, event.rangeStart < dayStart {
            return "Since start of day"
        }

        let formatter = AppDate.displayFormatter("HH:mm")

        if event.automaticCount > 1 {
            return "\(formatter.string(from: event.rangeStart))–\(formatter.string(from: event.startedAt))"
        }

        return formatter.string(from: event.startedAt)
    }
}
