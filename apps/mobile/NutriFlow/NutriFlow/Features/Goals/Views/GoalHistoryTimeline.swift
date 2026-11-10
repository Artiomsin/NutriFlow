import SwiftUI

/// One rendered change event: a goal version plus the fields it changed.
///
/// Consecutive automatic recalculations are merged into a single event so a
/// weight update does not flood the timeline with near-identical entries.
/// Manual and personalized changes are never merged.
struct GoalHistoryEvent: Identifiable {
    let id: String
    /// When the newest version in the event started.
    let startedAt: Date
    /// When the oldest version in the event started.
    let rangeStart: Date
    let endedAt: Date?
    let source: String
    let reason: String?
    let changes: [GoalMetricChange]
    let automaticCount: Int
}

struct GoalHistoryDayGroup: Identifiable {
    let id: String
    let date: Date
    let events: [GoalHistoryEvent]
}

enum GoalHistoryBuilder {
    /// Recalculations triggered by a profile or weight update within this
    /// window belong to the same visible event.
    static let automaticMergeWindow: TimeInterval = 60 * 60

    static func groups(
        from entries: [GoalVersionEntry],
        chronological: Bool
    ) -> [GoalHistoryDayGroup] {
        let events = entries
            .compactMap { entry -> GoalHistoryEvent? in
                guard let startedAt = AppDate.parseISO(entry.startedAt) else {
                    return nil
                }
                // A version that only switched source without changing values
                // has nothing to show.
                guard !entry.changes.isEmpty else { return nil }

                return GoalHistoryEvent(
                    id: entry.id,
                    startedAt: startedAt,
                    rangeStart: startedAt,
                    endedAt: entry.endedAt.flatMap(AppDate.parseISO),
                    source: entry.source,
                    reason: entry.reason,
                    changes: entry.changes,
                    automaticCount: 1
                )
            }
            .sorted { $0.startedAt > $1.startedAt }

        let merged = mergeAutomaticRecalculations(events)

        var groups: [GoalHistoryDayGroup] = []
        var currentDay: Date?
        var currentEvents: [GoalHistoryEvent] = []

        func flush() {
            guard let currentDay else { return }
            groups.append(
                GoalHistoryDayGroup(
                    id: dayID(for: currentDay),
                    date: currentDay,
                    events: chronological ? currentEvents.reversed() : currentEvents
                )
            )
        }

        for event in merged {
            let day = AppDate.calendar.startOfDay(for: event.rangeStart)

            if let currentDay, currentDay == day {
                currentEvents.append(event)
            } else {
                flush()
                currentDay = day
                currentEvents = [event]
            }
        }
        flush()

        return groups
    }

    private static func mergeAutomaticRecalculations(
        _ events: [GoalHistoryEvent]
    ) -> [GoalHistoryEvent] {
        var merged: [GoalHistoryEvent] = []

        for event in events {
            guard let previous = merged.last,
                  isAutomatic(previous.reason),
                  previous.reason == event.reason,
                  previous.source == event.source,
                  previous.startedAt.timeIntervalSince(event.rangeStart)
                    <= automaticMergeWindow
            else {
                merged.append(event)
                continue
            }

            merged[merged.count - 1] = merge(newer: previous, older: event)
        }

        return merged
    }

    /// Net diff of a series: `from` comes from the oldest version, `to` from
    /// the newest one, so intermediate recalculation steps collapse into the
    /// actual result without inventing values.
    private static func merge(
        newer: GoalHistoryEvent,
        older: GoalHistoryEvent
    ) -> GoalHistoryEvent {
        var changesByMetric: [String: GoalMetricChange] = [:]

        for change in newer.changes {
            changesByMetric[change.metric] = change
        }

        for change in older.changes {
            if let newerChange = changesByMetric[change.metric] {
                changesByMetric[change.metric] = GoalMetricChange(
                    metric: change.metric,
                    from: change.from,
                    to: newerChange.to
                )
            } else {
                changesByMetric[change.metric] = change
            }
        }

        let changes = changesByMetric.values.sorted {
            GoalHistoryFormat.order(of: $0.metric) < GoalHistoryFormat.order(of: $1.metric)
        }

        return GoalHistoryEvent(
            id: newer.id,
            startedAt: newer.startedAt,
            rangeStart: older.rangeStart,
            endedAt: older.endedAt,
            source: newer.source,
            reason: newer.reason,
            changes: changes,
            automaticCount: newer.automaticCount + 1
        )
    }

    private static func isAutomatic(_ reason: String?) -> Bool {
        reason == "profile_recalculation"
            || reason == "personalized_profile_recalculation"
    }

    private static func dayID(for date: Date) -> String {
        AppDate.dateOnlyFormatter().string(from: date)
    }
}

enum GoalHistoryFormat {
    private static let metrics = [
        "dailyCaloriesGoal",
        "dailyProteinGoal",
        "dailyFatGoal",
        "dailyCarbsGoal",
        "dailyWaterGoal",
        "dailyStepsGoal",
        "dailyActiveCaloriesGoal",
        "weeklyWorkoutsGoal",
        "weeklyWorkoutMinutesGoal",
        "nightlySleepMinMinutes",
        "nightlySleepMaxMinutes"
    ]

    static func order(of metric: String) -> Int {
        metrics.firstIndex(of: metric) ?? metrics.count
    }

    static func metricLabel(_ metric: String) -> String {
        switch metric {
        case "dailyCaloriesGoal": return "Calories"
        case "dailyProteinGoal": return "Protein"
        case "dailyFatGoal": return "Fat"
        case "dailyCarbsGoal": return "Carbs"
        case "dailyWaterGoal": return "Water"
        case "dailyStepsGoal": return "Steps"
        case "dailyActiveCaloriesGoal": return "Active calories"
        case "weeklyWorkoutsGoal": return "Workouts / week"
        case "weeklyWorkoutMinutesGoal": return "Workout minutes / week"
        case "nightlySleepMinMinutes": return "Sleep min / night"
        case "nightlySleepMaxMinutes": return "Sleep max / night"
        default: return metric
        }
    }

    static func sourceLabel(_ source: String) -> String {
        switch source.lowercased() {
        case "initial": return "Automatic"
        case "user": return "Manual"
        case "personalized": return "Personalized"
        default: return "Auto"
        }
    }

    static func reasonLabel(_ reason: String?) -> String? {
        switch reason {
        case "recommendation_accepted":
            return "Updated from a personalized recommendation"
        case "user_edit":
            return "Updated manually"
        case "manual_reset_to_automatic":
            return "Switched to automatic goals"
        case "profile_recalculation":
            return "Recalculated from profile and weight"
        case "personalized_profile_recalculation":
            return "Recalculated while keeping recommendation adjustments"
        case "initial_calculation":
            return "Initial automatic calculation"
        case nil, "":
            return nil
        default:
            return reason
        }
    }

    static func value(_ metric: String, _ value: Double?) -> String {
        guard let value else { return "—" }
        let number = value.formatted(.number.precision(.fractionLength(0...1)))

        switch metric {
        case "dailyProteinGoal", "dailyFatGoal", "dailyCarbsGoal":
            return "\(number) g"
        case "dailyWaterGoal":
            return "\(number) ml"
        case "weeklyWorkoutMinutesGoal",
             "nightlySleepMinMinutes",
             "nightlySleepMaxMinutes":
            return "\(number) min"
        default:
            return number
        }
    }
}

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
                VStack(alignment: .leading, spacing: 8) {
                    if showsDayHeaders {
                        Text(dayTitle(group.date))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(AppColors.textTertiary)
                            .padding(.leading, 2)
                    }

                    VStack(spacing: 8) {
                        ForEach(group.events) { event in
                            eventCard(event)
                        }
                    }
                }
            }
        }
    }

    private func eventCard(_ event: GoalHistoryEvent) -> some View {
        let isExpanded = expanded.contains(event.id)
        let visible = isExpanded
            ? event.changes
            : Array(event.changes.prefix(3))

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(timeText(event))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

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

    private func dayTitle(_ date: Date) -> String {
        let calendar = AppDate.calendar
        if calendar.isDateInToday(date) {
            return "Today"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        return AppDate.displayFormatter("d MMM yyyy").string(from: date)
    }
}
