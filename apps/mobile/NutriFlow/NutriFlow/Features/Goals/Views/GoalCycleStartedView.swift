import SwiftUI

/// Explicit completion state shown after the API creates a new goal cycle.
struct GoalCycleStartedView: View {
    let goals: UserGoals
    let goal: Goal?
    let targetWeight: String
    let maintainWeightMin: String
    let maintainWeightMax: String
    let weeklyRateKg: String
    let targetDate: String
    let estimatedCompletionDate: String?
    let preferredUnits: PreferredUnits
    let onDone: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                completionHeader
                planSection
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

            Text("New goal cycle started")
                .font(AppTypography.heading1)
                .foregroundStyle(AppColors.textPrimary)

            Text("Your previous cycle is saved in history. Your daily goals below have been recalculated for the new plan.")
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
            if !weeklyRateKg.isEmpty {
                LabeledContent("Weekly pace", value: "\(weeklyRateKg) kg/week")
            }
            if let targetDateDescription {
                LabeledContent("Target date", value: targetDateDescription)
            }
            if let estimatedCompletionDescription {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Label("Estimated completion", systemImage: "calendar.badge.clock")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColors.accent)
                    Text(estimatedCompletionDescription)
                        .font(.title3.bold())
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Based on your current weight and selected pace")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .appGlassSurface(level: .inset)
            }
        }
        .font(.subheadline)
        .foregroundStyle(AppColors.textSecondary)
        .padding(16)
        .appGlassSurface()
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

    private var estimatedCompletionDescription: String? {
        displayDate(estimatedCompletionDate)
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
