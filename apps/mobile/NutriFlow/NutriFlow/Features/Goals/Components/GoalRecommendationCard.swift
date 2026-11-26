import SwiftUI

struct GoalRecommendationCard: View {
    let recommendation: GoalRecommendation
    let isProcessing: Bool
    let onAccept: () -> Void
    let onDismiss: () -> Void

    @State private var prefsStore = PreferencesStore.shared

    private var baseline: GoalMetrics {
        // The recommendation includes an immutable snapshot of the goals it
        // was calculated from. Using it avoids presenting incorrect "from"
        // values if the active goals changed after this recommendation existed.
        recommendation.previousGoals
    }

    var body: some View {
        let rows = diffRows
        let planRows = suggestedPlanRows
        VStack(alignment: .leading, spacing: 14) {
            header
            evidenceLine
            if !rows.isEmpty {
                changeSection(title: "Daily goals", rows: rows)
            }
            if !planRows.isEmpty {
                changeSection(title: "Goal plan", rows: planRows)
            }
            if rows.isEmpty && planRows.isEmpty {
                Text("No goal values would change. You can keep your current goals.")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                Text("Only the values listed above will change. All other goals stay the same.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            if !reasons.isEmpty { reasonLines }
            buttons
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlassSurface()
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.accent)
            VStack(alignment: .leading, spacing: 2) {
                    Text("Suggested goal update")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                Text("Review the exact changes before applying them")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            confidenceChip
        }
    }

    private var confidenceChip: some View {
        let text = switch recommendation.confidence.level.lowercased() {
        case "high": "High"
        case "medium": "Medium"
        default: "Low"
        }
        return Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(AppColors.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(AppColors.accent.opacity(0.12))
            .cornerRadius(AppRadius.chip)
    }

    private var evidenceLine: some View {
        let confidence = recommendation.confidence
        let trackedDays = confidence.trackedDays
        let activityDays = confidence.activityDays

        return Text("Based on \(trackedDays) tracked days" + (activityDays > 0 ? " and \(activityDays) activity days." : "."))
            .font(.caption)
            .foregroundStyle(AppColors.textSecondary)
    }

    private func changeSection(title: String, rows: [DiffRow]) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(rows) { row in
                HStack(spacing: 10) {
                    Circle().fill(row.color).frame(width: 8, height: 8)
                    Text(row.label)
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text(row.from)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(AppColors.textTertiary)
                        .strikethrough()
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                    Text(row.to)
                        .font(.footnote.weight(.bold))
                        .foregroundColor(AppColors.textPrimary)
                }
            }
        }
        .padding(12)
        .appGlassSurface(level: .inset)
    }

    private var reasonLines: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(reasons.prefix(2)), id: \.self) { reason in
                Label(reason, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button {
                onAccept()
            } label: {
                Text("Apply changes")
                    .font(.headline)
                    .foregroundColor(AppColors.accentOnPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.accent)
                    .cornerRadius(AppRadius.medium)
            }
            Button {
                onDismiss()
            } label: {
                Text("Keep current goals")
                    .font(.headline)
                    .foregroundColor(AppColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .appGlassSurface(level: .inset)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(AppColors.accent, lineWidth: 1.5)
                    )
            }
        }
        .disabled(isProcessing)
        .opacity(isProcessing ? 0.6 : 1)
    }

    private var diffRows: [DiffRow] {
        let b = baseline
        let r = recommendation.recommendedGoals
        let prefs = prefsStore.preferredUnits

        func energy(_ v: Double?) -> String {
            guard let v else { return "" }
            return UnitConversion.formatEnergy(kcal: v, preferred: prefs)
        }
        func energyInt(_ v: Int?) -> String {
            guard let v else { return "" }
            return UnitConversion.formatEnergy(kcal: v, preferred: prefs)
        }
        func grams(_ v: Double?) -> String {
            v.map { "\($0.formatted(.number.precision(.fractionLength(0...1)))) g" } ?? ""
        }
        func plain(_ v: Int?) -> String { v.map { "\(number($0))" } ?? "" }
        func minutes(_ v: Int?) -> String { v.map { "\($0) min" } ?? "" }
        func sleep(_ v: Int?) -> String {
            guard let v else { return "" }
            return "\(v / 60)h \(v % 60)m"
        }

        var rows: [DiffRow] = []
        func add<V: Equatable>(_ id: String, _ label: String, _ color: Color, _ bv: V?, _ rv: V?, _ fmt: (V?) -> String) {
            guard let rv, rv != bv else { return }
            rows.append(DiffRow(id: id, label: label, color: color, from: fmt(bv), to: fmt(rv)))
        }

        add("calories", "Calories", .orange, b.dailyCaloriesGoal, r.dailyCaloriesGoal, energy)
        add("protein", "Protein", .yellow, b.dailyProteinGoal, r.dailyProteinGoal, grams)
        add("fat", "Fat", .purple, b.dailyFatGoal, r.dailyFatGoal, grams)
        add("carbs", "Carbs", .blue, b.dailyCarbsGoal, r.dailyCarbsGoal, grams)
        add("water", "Water", .cyan, b.dailyWaterGoal, r.dailyWaterGoal, { $0.map { "\($0) ml" } ?? "" })
        add("steps", "Steps", .green, b.dailyStepsGoal, r.dailyStepsGoal, plain)
        add("activeCalories", "Active calories", .orange, b.dailyActiveCaloriesGoal, r.dailyActiveCaloriesGoal, energyInt)
        add("workouts", "Workouts / week", .pink, b.weeklyWorkoutsGoal, r.weeklyWorkoutsGoal, plain)
        add("workoutMinutes", "Workout minutes / week", .indigo, b.weeklyWorkoutMinutesGoal, r.weeklyWorkoutMinutesGoal, minutes)
        add("sleep", "Sleep / night", .purple, b.nightlySleepMinMinutes, r.nightlySleepMinMinutes, sleep)
        return rows
    }

    private var suggestedPlanRows: [DiffRow] {
        guard let plan = recommendation.suggestedPlan else { return [] }

        var rows: [DiffRow] = []
        func add<V: Equatable>(
            _ id: String,
            _ label: String,
            _ previous: V?,
            _ proposed: V?,
            format: (V?) -> String
        ) {
            guard proposed != previous else { return }
            rows.append(
                DiffRow(
                    id: id,
                    label: label,
                    color: AppColors.accent,
                    from: format(previous),
                    to: format(proposed)
                )
            )
        }

        add(
            "weeklyPace",
            "Weekly pace",
            plan.previousWeeklyRateKg,
            plan.weeklyRateKg,
            format: { value in
                value.map { "\($0.formatted(.number.precision(.fractionLength(0...2)))) kg/week" } ?? "Not set"
            }
        )
        add(
            "targetDate",
            "Estimated target date",
            plan.previousTargetDate,
            plan.targetDate,
            format: displayDate
        )
        return rows
    }

    private var reasons: [String] { recommendation.reasons }

    private func number(_ v: Int) -> String {
        NumberFormatter.goalDiffGrouping.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    private func displayDate(_ value: String?) -> String {
        guard let value else { return "Not set" }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: value) else { return value }
        return AppDate.displayFormatter("d MMM yyyy").string(from: date)
    }
}

private struct DiffRow: Identifiable {
    let id: String
    let label: String
    let color: Color
    let from: String
    let to: String
}

struct GoalPersonalizationSection: View {
    let state: PersonalizationState?
    let goals: UserGoals?
    let isProcessing: Bool
    let error: AppError?
    let onRetry: () -> Void
    let onRequest: () -> Void
    let onAccept: (GoalRecommendation) -> Void
    let onDismiss: (GoalRecommendation) -> Void

    var body: some View {
        VStack(spacing: 12) {
            if let error {
                ErrorView(error: error, onRetry: onRetry)
            }
            if let pending = state?.pending {
                GoalRecommendationCard(
                    recommendation: pending,
                    isProcessing: isProcessing,
                    onAccept: { onAccept(pending) },
                    onDismiss: { onDismiss(pending) }
                )
            } else if state?.personalizationDue == true {
                Button {
                    onRequest()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .foregroundColor(AppColors.accent)
                        Text("Update my goals to match my stats")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .appGlassSurface(level: .inset)
                }
                .disabled(isProcessing)
                .opacity(isProcessing ? 0.6 : 1)
            } else if let nextAvailableAt = state?.nextAvailableAt {
                NextGoalReviewCard(nextAvailableAt: nextAvailableAt)
            }
        }
    }
}

private struct NextGoalReviewCard: View {
    let nextAvailableAt: String

    private var availableDate: Date? {
        let withFractionalSeconds = ISO8601DateFormatter()
        withFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFractionalSeconds.date(from: nextAvailableAt)
            ?? ISO8601DateFormatter().date(from: nextAvailableAt)
    }

    private var dateText: String {
        guard let availableDate else { return "soon" }
        return AppDate.displayFormatter("d MMMM").string(from: availableDate)
    }

    private var relativeText: String? {
        guard let availableDate else { return nil }
        return RelativeDateTimeFormatter().localizedString(
            for: availableDate,
            relativeTo: Date()
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "clock.badge.checkmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 32, height: 32)
                .background(AppColors.accent.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Next goal review")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text("Available (dateText)" + (relativeText.map { " · \($0)" } ?? ""))
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Text("We need a little more recent data before creating another recommendation.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlassSurface()
    }
}

private extension NumberFormatter {
    static let goalDiffGrouping: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

#Preview("Pending recommendation") {
    let goals = UserGoals(
        id: "1", userId: "1",
        dailyCaloriesGoal: 2200, dailyProteinGoal: 150,
        dailyFatGoal: 65, dailyCarbsGoal: 250, dailyWaterGoal: 3000,
        dailyStepsGoal: 8000, dailyActiveCaloriesGoal: 500,
        weeklyWorkoutsGoal: 5, weeklyWorkoutMinutesGoal: 155,
        nightlySleepMinMinutes: 234, nightlySleepMaxMinutes: 500,
        source: "initial", createdAt: nil, updatedAt: nil
    )
    let rec = GoalRecommendation(
        id: "rec-1", userId: "1", status: "pending",
        previousGoals: GoalMetrics(
            dailyCaloriesGoal: 2200, dailyProteinGoal: 150,
            dailyFatGoal: 65, dailyCarbsGoal: 250, dailyWaterGoal: 3000,
            dailyStepsGoal: 8000, dailyActiveCaloriesGoal: 500,
            weeklyWorkoutsGoal: 5, weeklyWorkoutMinutesGoal: 155,
            nightlySleepMinMinutes: 234, nightlySleepMaxMinutes: 500
        ),
        recommendedGoals: GoalMetrics(
            dailyCaloriesGoal: 2050, dailyProteinGoal: 160,
            dailyFatGoal: 60, dailyCarbsGoal: 230, dailyWaterGoal: 3000,
            dailyStepsGoal: 9000, dailyActiveCaloriesGoal: 550,
            weeklyWorkoutsGoal: 6, weeklyWorkoutMinutesGoal: 180,
            nightlySleepMinMinutes: 240, nightlySleepMaxMinutes: 510
        ),
        analysisPeriodStart: "2026-09-03", analysisPeriodEnd: "2026-09-17",
        reasons: [
            "Your weekly calories were 10% below target",
            "Your average sleep is shorter than the recommended range"
        ],
        confidence: RecommendationConfidence(
            level: "high", dataQualityScore: 0.87, trackedDays: 14,
            weightLogsCount: 0, activityDays: 12, workoutCount: 4,
            sleepNights: 14, adherenceStepsPct: 0.72, weightTrendKgPerWeek: nil
        ),
        createdAt: "2026-09-17T08:00:00Z", expiresAt: "2026-09-24T08:00:00Z",
        acceptedAt: nil, dismissedAt: nil, suggestedPlan: nil
    )
    return VStack(spacing: 20) {
        GoalPersonalizationSection(
            state: PersonalizationState(pending: rec, personalizationDue: false, nextAvailableAt: nil),
            goals: goals,
            isProcessing: false,
            error: nil,
            onRetry: {},
            onRequest: {},
            onAccept: { _ in },
            onDismiss: { _ in }
        )
    }
    .padding(.horizontal, AppSpacing.paddingHorizontal)
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}

#Preview("Due, no pending") {
    GoalPersonalizationSection(
        state: PersonalizationState(pending: nil, personalizationDue: true, nextAvailableAt: nil),
        goals: nil,
        isProcessing: false,
        error: nil,
        onRetry: {},
        onRequest: {},
        onAccept: { _ in },
        onDismiss: { _ in }
    )
    .padding(.horizontal, AppSpacing.paddingHorizontal)
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
