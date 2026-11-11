
import SwiftUI

struct GoalHistoryTimeline: View {
    let entries: [GoalVersionEntry]

    var dayStart: Date? = nil
    var chronological: Bool = false
    var showsDayHeaders: Bool = true

    @State private var expanded: Set<String> = []
    @State private var selectedFilter: HistoryFilter = .all

    private enum HistoryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case automatic = "Automatic"
        case personalized = "Personalized"
        case manual = "Manual"

        var id: String { rawValue }

        func matches(_ event: GoalHistoryEvent) -> Bool {
            let source = event.source.lowercased()
            let reason = event.reason?.lowercased()

            switch self {
            case .all:
                return true
            case .automatic:
                return source == "initial"
                    || reason == "initial_calculation"
                    || reason == "profile_recalculation"
            case .personalized:
                return source == "personalized"
                    || reason == "recommendation_accepted"
                    || reason == "personalized_profile_recalculation"
            case .manual:
                return source == "user"
                    || reason == "user_edit"
            }
        }
    }

    private var groups: [GoalHistoryDayGroup] {
        GoalHistoryBuilder.groups(
            from: entries,
            chronological: chronological
        )
    }

    private var filteredGroups: [GoalHistoryDayGroup] {
        groups.compactMap { group in
            let events = group.events.filter {
                selectedFilter.matches($0)
            }

            guard !events.isEmpty else { return nil }

            return GoalHistoryDayGroup(
                id: group.id,
                date: group.date,
                events: events
            )
        }
    }

    private var visibleEvents: [GoalHistoryEvent] {
        filteredGroups.flatMap(\.events)
    }

    private var latestEventID: String? {
        chronological
            ? visibleEvents.last?.id
            : visibleEvents.first?.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            summary
            filters

            if filteredGroups.isEmpty {
                emptyFilterState
            } else {
                timeline
            }
        }
    }

    private var summary: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(visibleEvents.count)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.textPrimary)

                Text(visibleEvents.count == 1 ? "Goal update" : "Goal updates")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)

                Text("Your goals have evolved over time")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textTertiary)
            }

            Spacer()

            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(AppColors.accent)
                .frame(width: 52, height: 52)
                .background(
                    AppColors.accent.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 16)
                )
        }
        .padding(16)
        .appGlassSurface()
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HistoryFilter.allCases) { filter in
                    let isSelected = selectedFilter == filter

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(
                                isSelected
                                    ? AppColors.accentOnPrimary
                                    : AppColors.textSecondary
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background {
                                Capsule()
                                    .fill(
                                        isSelected
                                            ? AppColors.accent
                                            : AppColors.surfaceSecondary
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(filteredGroups.enumerated()), id: \.offset) { index, group in
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
                                expanded: $expanded,
                                isLatest: event.id == latestEventID
                            )
                        }
                    }
                }
            }
        }
    }

    private var emptyFilterState: some View {
        VStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 24))
                .foregroundStyle(AppColors.textTertiary)

            Text("No updates in this category")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)

            Text("Try selecting another filter.")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .appGlassSurface()
    }
}

