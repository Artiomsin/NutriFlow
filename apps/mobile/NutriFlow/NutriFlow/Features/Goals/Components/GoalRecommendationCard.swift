import SwiftUI

struct GoalRecommendationCard: View {
    let recommendation: GoalRecommendation
    let currentGoals: UserGoals?
    let isProcessing: Bool
    let onAccept: () -> Void
    let onDismiss: () -> Void

    @State private var prefsStore = PreferencesStore.shared

    private var baseline: GoalMetrics {
        GoalMetrics(
            dailyCaloriesGoal: currentGoals?.dailyCaloriesGoal,
            dailyProteinGoal: currentGoals?.dailyProteinGoal,
            dailyFatGoal: currentGoals?.dailyFatGoal,
            dailyCarbsGoal: currentGoals?.dailyCarbsGoal,
            dailyWaterGoal: currentGoals?.dailyWaterGoal,
            dailyStepsGoal: currentGoals?.dailyStepsGoal,
            dailyActiveCaloriesGoal: currentGoals?.dailyActiveCaloriesGoal,
            weeklyWorkoutsGoal: currentGoals?.weeklyWorkoutsGoal,
            weeklyWorkoutMinutesGoal: currentGoals?.weeklyWorkoutMinutesGoal,
            nightlySleepMinMinutes: currentGoals?.nightlySleepMinMinutes,
            nightlySleepMaxMinutes: currentGoals?.nightlySleepMaxMinutes
        )
    }

    var body: some View {
        let rows = diffRows
        VStack(alignment: .leading, spacing: 14) {
            header
            if !rows.isEmpty { diffList(rows) }
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
                Text("Goal recommendations")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                Text("Based on your recent activity")
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

    private func diffList(_ rows: [DiffRow]) -> some View {
        VStack(spacing: 8) {
            ForEach(rows) { row in
                HStack(spacing: 10) {
                    Circle().fill(row.color).frame(width: 8, height: 8)
                    Text(row.label)
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text(row.from)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(AppColors.textTertiary )
                        .strikethrough()
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                    Text(row.to)
                        .font(.footnote.weight(.bold))
                        .foregroundColor(AppColors.textPrimary)
                }
            }
            if let extra = rows.count > 3 ? rows.count - 3 : nil {
                Text("+\(extra) more goals updated")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 2)
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
                Text("Apply")
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
                Text("Dismiss")
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

        func energy(_ v: Int?) -> String {
            guard let v else { return "" }
            return "\(UnitConversion.formatEnergyValue(kcal: v, preferred: prefs)) \(UnitConversion.formatEnergyUnit(preferred: prefs))"
        }
        func grams(_ v: Int?) -> String { v.map { "\($0) g" } ?? "" }
        func plain(_ v: Int?) -> String { v.map { "\(number($0))" } ?? "" }
        func minutes(_ v: Int?) -> String { v.map { "\($0) min" } ?? "" }
        func sleep(_ v: Int?) -> String {
            guard let v else { return "" }
            return "\(v / 60)h \(v % 60)m"
        }

        var rows: [DiffRow] = []
        func add(_ id: String, _ label: String, _ color: Color, _ bv: Int?, _ rv: Int?, _ fmt: (Int?) -> String) {
            guard let rv, rv != bv else { return }
            rows.append(DiffRow(id: id, label: label, color: color, from: fmt(bv), to: fmt(rv)))
        }

        add("calories", "Calories", .orange, b.dailyCaloriesGoal, r.dailyCaloriesGoal, energy)
        add("protein", "Protein", .yellow, b.dailyProteinGoal, r.dailyProteinGoal, grams)
        add("fat", "Fat", .purple, b.dailyFatGoal, r.dailyFatGoal, grams)
        add("carbs", "Carbs", .blue, b.dailyCarbsGoal, r.dailyCarbsGoal, grams)
        add("water", "Water", .cyan, b.dailyWaterGoal, r.dailyWaterGoal, { $0.map { "\($0) ml" } ?? "" })
        add("steps", "Steps", .green, b.dailyStepsGoal, r.dailyStepsGoal, plain)
        add("activeCalories", "Active calories", .orange, b.dailyActiveCaloriesGoal, r.dailyActiveCaloriesGoal, energy)
        add("workouts", "Workouts / week", .pink, b.weeklyWorkoutsGoal, r.weeklyWorkoutsGoal, plain)
        add("workoutMinutes", "Workout minutes / week", .indigo, b.weeklyWorkoutMinutesGoal, r.weeklyWorkoutMinutesGoal, minutes)
        add("sleep", "Sleep / night", .purple, b.nightlySleepMinMinutes, r.nightlySleepMinMinutes, sleep)
        return rows
    }

    private var reasons: [String] { recommendation.reasons }

    private func number(_ v: Int) -> String {
        NumberFormatter.goalDiffGrouping.string(from: NSNumber(value: v)) ?? "\(v)"
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
    let onRequest: () -> Void
    let onAccept: (GoalRecommendation) -> Void
    let onDismiss: (GoalRecommendation) -> Void

    var body: some View {
        if let pending = state?.pending {
            GoalRecommendationCard(
                recommendation: pending,
                currentGoals: goals,
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
        }
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
        acceptedAt: nil, dismissedAt: nil
    )
    return VStack(spacing: 20) {
        GoalPersonalizationSection(
            state: PersonalizationState(pending: rec, personalizationDue: false),
            goals: goals,
            isProcessing: false,
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
        state: PersonalizationState(pending: nil, personalizationDue: true),
        goals: nil,
        isProcessing: false,
        onRequest: {},
        onAccept: { _ in },
        onDismiss: { _ in }
    )
    .padding(.horizontal, AppSpacing.paddingHorizontal)
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
