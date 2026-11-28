import SwiftUI

/// Compact plan state for the Goals manager. Manual fields are managed here so
/// the individual goal rows stay clean.
struct GoalPlanSummaryCard: View {
    let goals: UserGoals
    let preview: GoalsPreview?
    let isProcessing: Bool
    let onClearOverride: (GoalMetricKey) async -> Bool

    @State private var showFixedFields = false
    @State private var clearingMetrics: Set<GoalMetricKey> = []
    @State private var prefsStore = PreferencesStore.shared

    private var isManual: Bool {
        goals.mode == .manual || goals.source == "user"
    }

    private var fixedMetrics: [GoalMetricKey] {
        if let fixed = goals.fixedMetrics {
            return GoalMetricKey.allCases.filter { fixed.contains($0) }
        }
        if let overrides = goals.manualOverrides {
            return GoalMetricKey.allCases.filter { overrides[$0] != nil }
        }
        return []
    }

    private var modeText: String {
        guard isManual else { return "Automatic" }
        guard !fixedMetrics.isEmpty else { return "Manual" }
        return "Manual · \(fixedMetrics.count) fields fixed"
    }

    private var targetText: String? {
        let unit = UnitConversion.bodyWeightUnitLabel(preferred: prefsStore.preferredUnits)
        let current = preview?.basis?.currentWeightKg.map {
            UnitConversion.formatBodyWeight(kg: $0, preferred: prefsStore.preferredUnits)
        }
        let target = preview?.basis?.targetWeightKg.map {
            UnitConversion.formatBodyWeight(kg: $0, preferred: prefsStore.preferredUnits)
        }
        switch (current, target) {
        case let (current?, target?):
            return "\(current) → \(target) \(unit)"
        case let (current?, nil):
            return "\(current) \(unit)"
        case let (nil, target?):
            return "\(target) \(unit)"
        default:
            return nil
        }
    }

    private var paceText: String? {
        let rate = preview?.calories?.targetRateKgPerWeek
            ?? preview?.estimatedCompletion?.targetRateKgPerWeek
            ?? preview?.basis?.weeklyRateKg
        guard let rate else { return nil }
        let value = abs(rate).formatted(.number.precision(.fractionLength(0...2)))
        return "\(value) kg/week"
    }

    private var estimatedCompletionText: String {
        if let date = displayDate(preview?.estimatedCompletion?.plannedDate
                                  ?? preview?.estimatedCompletion?.byTrendDate) {
            return date
        }
        return "Calculated from your pace"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let direction = preview?.basis?.goal {
                row(title: "Direction", value: direction.displayName)
            }
            if let targetText {
                row(title: "Target", value: targetText)
            }
            if let targetDate = displayDate(preview?.basis?.targetDate) {
                row(title: "Target date", value: targetDate)
            }
            if let paceText {
                row(title: "Pace", value: paceText)
            }
            row(title: "Estimated completion", value: estimatedCompletionText)

            if isManual && !fixedMetrics.isEmpty {
                Divider().opacity(0.3)
                fixedFieldsControl
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlassSurface()
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColors.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Goal plan")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Text(modeText)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer(minLength: 8)
        }
    }

    @ViewBuilder
    private var fixedFieldsControl: some View {
        DisclosureGroup(isExpanded: $showFixedFields) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(fixedMetrics, id: \.self) { metric in
                    HStack(spacing: 10) {
                        Text(Self.label(for: metric))
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer(minLength: 8)
                        Button {
                            Task { await clear(metric) }
                        } label: {
                            if clearingMetrics.contains(metric) {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Text("Use automatic")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColors.accent)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isProcessing || !clearingMetrics.isEmpty)
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text("Manage fixed fields")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColors.accent)
                Spacer()
                Text("\(fixedMetrics.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
    }

    private func row(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func clear(_ metric: GoalMetricKey) async {
        guard !clearingMetrics.contains(metric) else { return }
        clearingMetrics.insert(metric)
        defer { clearingMetrics.remove(metric) }
        _ = await onClearOverride(metric)
    }

    private func displayDate(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        let date = AppDate.dateOnlyFormatter().date(from: value) ?? AppDate.parseISO(value)
        guard let date else { return value }
        return AppDate.displayFormatter("d MMM yyyy").string(from: date)
    }

    private static func label(for metric: GoalMetricKey) -> String {
        switch metric {
        case .dailyCaloriesGoal: return "Calories"
        case .dailyProteinGoal: return "Protein"
        case .dailyFatGoal: return "Fat"
        case .dailyCarbsGoal: return "Carbs"
        case .dailyWaterGoal: return "Water"
        case .dailyStepsGoal: return "Steps"
        case .dailyActiveCaloriesGoal: return "Active calories"
        case .weeklyWorkoutsGoal: return "Workouts"
        case .weeklyWorkoutMinutesGoal: return "Workout minutes"
        case .nightlySleepMinMinutes: return "Min sleep"
        case .nightlySleepMaxMinutes: return "Max sleep"
        }
    }
}
