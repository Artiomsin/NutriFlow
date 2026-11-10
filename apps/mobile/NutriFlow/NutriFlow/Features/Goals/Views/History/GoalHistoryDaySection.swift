
import SwiftUI

struct GoalHistoryDaySection: View {
    let group: GoalHistoryDayGroup
    let dayStart: Date?

    @Binding var expanded: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(dayTitle(group.date))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textTertiary)
                .padding(.leading, 2)

            VStack(spacing: 10) {
                ForEach(group.events) { event in
                    GoalHistoryCard(
                        event: event,
                        dayStart: dayStart,
                        expanded: $expanded
                    )
                }
            }
        }
    }

    private func dayTitle(_ date: Date) -> String {
        let calendar = AppDate.calendar

        if calendar.isDateInToday(date) {
            return "Today"
        }

        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        return AppDate.displayFormatter("d MMM yyyy")
            .string(from: date)
    }
}

