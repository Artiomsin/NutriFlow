import SwiftUI

/// Explicit completion state shown after the API creates a new goal cycle.
struct GoalCycleStartedView: View {
    let goals: UserGoals
    let startedNewCycle: Bool
    let goal: Goal?
    let targetWeight: String
    let maintainWeightMin: String
    let maintainWeightMax: String
    let weeklyRateKg: String
    let targetDate: String
    let preview: GoalsPreview?
    let preferredUnits: PreferredUnits
    let onDone: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                completionHeader
                planSection
                planOutcomeSection
                goalsSection
                PrimaryButton(title: "Done", action: onDone)
            }
            .padding(.horizontal, AppSpacing.paddingHorizontal)
            .padding(.vertical, 24)
        }
    }

    private var completionHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(AppColors.success)
                .accessibilityHidden(true)

            Text(startedNewCycle ? "New goal cycle started" : "Goal plan updated")
                .font(AppTypography.heading1)
                .foregroundStyle(AppColors.textPrimary)

            Text(completionMessage)
                .font(.body)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("New plan", systemImage: "target")
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)

            LabeledContent("Direction", value: goal?.displayName ?? "Not set")
            if let targetDescription {
                LabeledContent("Target", value: targetDescription)
            }
            if !weeklyRateKg.isEmpty, preview?.calories?.targetRateKgPerWeek == nil {
                LabeledContent("Weekly pace", value: "\(weeklyRateKg) kg/week")
            }
            if let targetDateDescription, preview?.estimatedCompletion == nil {
                LabeledContent("Target date", value: targetDateDescription)
            }
        }
        .font(.subheadline)
        .foregroundStyle(AppColors.textSecondary)
        .padding(16)
        .appGlassSurface()
    }

    private var completionMessage: String {
        if startedNewCycle {
            return "Your previous cycle is saved in history. Your daily goals below have been recalculated for the new plan."
        }
        if goals.mode == .manual || goals.source == "user" {
            return "Your plan is active. Your manual daily goals stay unchanged; review any recommendation in Goals."
        }
        return "Your plan is active. We checked its pace and recalculated your daily goals where needed."
    }

    @ViewBuilder
    private var planOutcomeSection: some View {
        if let preview, let completion = preview.estimatedCompletion {
            GoalPlanTimelineCard(preview: preview, completion: completion)
        }
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Updated daily goals", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(goalRows, id: \.title) { row in
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: icon(for: row.title))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.accent)
                        Text(row.title)
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                        Text(row.value)
                            .font(.subheadline.bold())
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                    .padding(14)
                    .appGlassSurface(level: .inset)
                }
            }
        }
    }

    private var targetDescription: String? {
        switch goal {
        case .lose, .gain:
            guard !targetWeight.isEmpty else { return nil }
            return "\(targetWeight) \(UnitConversion.bodyWeightUnitLabel(preferred: preferredUnits))"
        case .maintain:
            guard !maintainWeightMin.isEmpty, !maintainWeightMax.isEmpty else { return nil }
            let unit = UnitConversion.bodyWeightUnitLabel(preferred: preferredUnits)
            return "\(maintainWeightMin)–\(maintainWeightMax) \(unit)"
        case nil:
            return nil
        }
    }

    private var targetDateDescription: String? {
        displayDate(targetDate)
    }

    private func displayDate(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        guard let date = AppDate.dateOnlyFormatter().date(from: value) else { return value }
        return AppDate.displayFormatter("d MMM yyyy").string(from: date)
    }

    private func icon(for title: String) -> String {
        switch title {
        case "Calories": "flame.fill"
        case "Protein": "bolt.fill"
        case "Carbohydrates": "leaf.fill"
        case "Fat": "drop.fill"
        case "Water": "drop.fill"
        case "Steps": "figure.walk"
        default: "target"
        }
    }

    private var goalRows: [(title: String, value: String)] {
        var rows: [(title: String, value: String)] = []
        if let calories = goals.dailyCaloriesGoal {
            rows.append(("Calories", UnitConversion.formatEnergy(kcal: calories, preferred: preferredUnits)))
        }
        if let protein = goals.dailyProteinGoal {
            rows.append(("Protein", "\(protein.formatted(.number.precision(.fractionLength(0)))) g"))
        }
        if let carbs = goals.dailyCarbsGoal {
            rows.append(("Carbohydrates", "\(carbs.formatted(.number.precision(.fractionLength(0)))) g"))
        }
        if let fat = goals.dailyFatGoal {
            rows.append(("Fat", "\(fat.formatted(.number.precision(.fractionLength(0)))) g"))
        }
        if let water = goals.dailyWaterGoal {
            rows.append(("Water", "\(water.formatted()) ml"))
        }
        if let steps = goals.dailyStepsGoal {
            rows.append(("Steps", steps.formatted()))
        }
        return rows
    }
}
