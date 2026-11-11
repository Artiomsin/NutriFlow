import Foundation

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
