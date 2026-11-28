import SwiftUI

enum GoalPlanCompletion: Equatable {
    case planUpdated
    case newCycle
    case automaticEnabled
}

/// Explicit completion state shown after the API applies a goal plan change.
struct GoalCycleStartedView: View {
    let goals: UserGoals
    let completion: GoalPlanCompletion
    let goal: Goal?
    let targetWeight: String
    let maintainWeightMin: String
    let maintainWeightMax: String
    let weeklyRateKg: String
    let targetDate: String
    let preview: GoalsPreview?
    let appliedChanges: [GoalChangeSummaryCard.Change]
    let preferredUnits: PreferredUnits
    let isApplyingAutomatic: Bool
    let onUseAutomatic: (() async -> Bool)?
    let isApplyingSuggestion: Bool
    let suggestionResolution: String?
    let onApplySuggestion: (() async -> Bool)?
    let onKeepSuggestion: (() async -> Bool)?
    let onDone: () -> Void

    private var isManual: Bool {
        goals.mode == .manual || goals.source == "user"
    }

    private var showsSuggestionCard: Bool {
        goals.hasPendingSuggestion == true
            && goals.suggestion != nil
            && (onApplySuggestion != nil || onKeepSuggestion != nil)
    }

    private var showsAutomaticOffer: Bool {
        completion == .planUpdated
            && isManual
            && onUseAutomatic != nil
            && !showsSuggestionCard
            && suggestionResolution == nil
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                completionHeader
                planSection
                planOutcomeSection
                if !appliedChanges.isEmpty {
                    GoalChangeSummaryCard(changes: appliedChanges)
                }
                if let suggestionResolution {
                    resolutionBanner(suggestionResolution)
                }
                if showsSuggestionCard, let suggestion = goals.suggestion {
                    suggestionSection(suggestion: suggestion)
                }
                if showsAutomaticOffer {
                    automaticOffer
                }
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

            Text(completionTitle)
                .font(AppTypography.heading1)
                .foregroundStyle(AppColors.textPrimary)

            Text(completionMessage)
                .font(.body)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private var completionTitle: String {
        switch completion {
        case .newCycle:
            return "New goal cycle started"
        case .automaticEnabled:
            return "Automatic goals enabled"
        case .planUpdated:
            return "Goal plan updated"
        }
    }

    private var completionMessage: String {
        switch completion {
        case .newCycle:
            return "Your previous cycle is saved in history. Your daily goals below have been recalculated for the new plan."
        case .automaticEnabled:
            return "Your daily goals below were recalculated from your current profile and this plan."
        case .planUpdated:
            if isManual {
                if showsSuggestionCard {
                    return "Your plan is active. Your manual daily goals stay unchanged; review the recalculated values below."
                }
                return "Your plan is active. Your manual daily goals stay unchanged."
            }
            return "Your plan is active. We checked its pace and recalculated your daily goals where needed."
        }
    }

    private var automaticOffer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your manual daily goals were kept.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            Text("Recalculate them automatically for this plan?")
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)

            Button {
                Task { _ = await onUseAutomatic?() }
            } label: {
                HStack {
                    if isApplyingAutomatic {
                        ProgressView()
                            .tint(AppColors.accent)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isApplyingAutomatic ? "Recalculating…" : "Use automatic goals")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(AppColors.accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
            }
            .disabled(isApplyingAutomatic)
        }
        .padding(12)
        .appGlassSurface()
    }

    private func resolutionBanner(_ message: String) -> some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppColors.success)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appGlassSurface(level: .inset)
    }

    private func suggestionSection(suggestion: GoalSuggestion) -> some View {
        GoalSuggestionCard(
            suggestion: suggestion,
            isProcessing: isApplyingSuggestion,
            onApply: {
                Task { _ = await onApplySuggestion?() }
            },
            onKeep: {
                Task { _ = await onKeepSuggestion?() }
            }
        )
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

    private var goalsSectionTitle: String {
        completion == .planUpdated && isManual
            ? "Current daily goals"
            : "Updated daily goals"
    }

    @ViewBuilder
    private var planOutcomeSection: some View {
        if let preview, let completion = preview.estimatedCompletion {
            GoalPlanTimelineCard(preview: preview, completion: completion)
        }
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(goalsSectionTitle, systemImage: "sparkles")
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
            rows.append(("Protein", "\(protein.formatted(.number.precision(.fractionLength(1)))) g"))
        }
        if let carbs = goals.dailyCarbsGoal {
            rows.append(("Carbohydrates", "\(carbs.formatted(.number.precision(.fractionLength(1)))) g"))
        }
        if let fat = goals.dailyFatGoal {
            rows.append(("Fat", "\(fat.formatted(.number.precision(.fractionLength(1)))) g"))
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
