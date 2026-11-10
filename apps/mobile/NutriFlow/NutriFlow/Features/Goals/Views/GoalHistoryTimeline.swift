import SwiftUI

/// Построение всей временной шкалы изменений целей.
///
/// Получает версии целей, группирует их по дням через `GoalHistoryBuilder`
/// и отображает каждую группу как секцию дня с карточками событий.
struct GoalHistoryTimeline: View {
    let entries: [GoalVersionEntry]
    /// In the day detail sheet, versions that started earlier are labelled as
    /// active since the beginning of the day.
    var dayStart: Date? = nil
    /// Oldest first reads better inside a single day.
    var chronological: Bool = false
    var showsDayHeaders: Bool = true

    @State private var expanded: Set<String> = []

    private var groups: [GoalHistoryDayGroup] {
        GoalHistoryBuilder.groups(from: entries, chronological: chronological)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(groups) { group in
                if showsDayHeaders {
                    GoalHistoryDaySection(
                        group: group,
                        dayStart: dayStart,
                        expanded: $expanded
                    )
                } else {
                    VStack(spacing: 8) {
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
        }
    }
}
