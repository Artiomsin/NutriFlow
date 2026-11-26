import SwiftUI

/// Edits the active goal plan. A changed direction is deliberately sent through
/// the new-cycle endpoint, while changes within the same direction update the
/// current cycle in place.
struct GoalPlanView: View {
    private enum Field: Hashable {
        case targetWeight
        case weeklyPace
        case maintainMinimum
        case maintainMaximum
    }

    @Bindable var profileVM: ProfileViewModel
    @Bindable var goalsVM: GoalsViewModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var isSaving = false
    @State private var showNewCycleConfirmation = false
    @State private var pendingNewCycle: NewGoalCycleRequest?
    @State private var startedCycleGoals: UserGoals?

    var body: some View {
        Group {
            if let startedCycleGoals {
                GoalCycleStartedView(
                    goals: startedCycleGoals,
                    goal: profileVM.goal,
                    targetWeight: profileVM.targetWeight,
                    maintainWeightMin: profileVM.maintainWeightMin,
                    maintainWeightMax: profileVM.maintainWeightMax,
                    weeklyRateKg: profileVM.weeklyRateKg,
                    targetDate: profileVM.targetDate,
                    estimatedCompletionDate: goalsVM.preview?.estimatedCompletion?.plannedDate,
                    preferredUnits: profileVM.preferredUnits,
                    onDone: { dismiss() }
                )
            } else {
                planEditor
            }
        }
        .background(AppColors.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var planEditor: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Goal plan")
                    .font(AppTypography.heading1)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Update the plan for your current goal, or choose a new direction to start a new cycle.")
                    .font(.body)
                    .foregroundStyle(AppColors.textSecondary)

                directionSection
                planFields
                errorSection
                saveButton
            }
            .padding(.horizontal, AppSpacing.paddingHorizontal)
            .padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        // This screen can be opened again after a cycle was created elsewhere.
        // Always use the server's active cycle rather than values left in the
        // shared profile form from a previous visit.
        .task {
            await profileVM.loadData(forceRefresh: true)
        }
        .confirmationDialog(
            "Start a new goal cycle?",
            isPresented: $showNewCycleConfirmation,
            titleVisibility: .visible
        ) {
            Button("Start new cycle") {
                startNewCycle()
            }
            Button("Keep current cycle", role: .cancel) {
                pendingNewCycle = nil
            }
        } message: {
            Text("Your previous goal will remain in history. New daily goals will be calculated for the direction and plan below.")
        }
        .onChange(of: profileVM.targetWeight) { _, _ in
            profileVM.validateLiveValue(.targetWeight)
        }
        .onChange(of: profileVM.maintainWeightMin) { _, _ in
            profileVM.validateLiveValue(.maintainRange)
        }
        .onChange(of: profileVM.maintainWeightMax) { _, _ in
            profileVM.validateLiveValue(.maintainRange)
        }
        .onChange(of: profileVM.weeklyRateKg) { _, _ in
            profileVM.validateLiveValue(.weeklyPace)
        }
        .onChange(of: profileVM.targetDate) { _, _ in
            profileVM.clearFieldError("targetDate")
        }
    }

    private var directionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Direction")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            Text("Changing this starts a separate goal cycle.")
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: 10) { directionChoices }

            if let goal = profileVM.goal {
                Text(directionDetail(for: goal))
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }

            if let error = profileVM.fieldErrors["goal"] {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppColors.error)
            }
        }
        .padding(16)
        .appGlassSurface()
    }

    @ViewBuilder
    private var directionChoices: some View {
        ForEach(Goal.allCases, id: \.self) { goal in
            GoalDirectionChoice(
                goal: goal,
                isSelected: profileVM.goal == goal
            ) {
                select(goal)
            }
        }
    }

    @ViewBuilder
    private var planFields: some View {
        switch profileVM.goal {
        case .lose, .gain:
            targetPlanFields
        case .maintain:
            maintainPlanFields
        case nil:
            EmptyView()
        }
    }

    private var targetPlanFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Target and schedule")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            Text("Set either a pace, a date, or both. When both are set, pace takes priority for the estimate.")
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)

            AppTextField(
                title: "Target weight (\(UnitConversion.bodyWeightUnitLabel(preferred: profileVM.preferredUnits)))",
                text: $profileVM.targetWeight,
                keyboardType: .decimalPad,
                focus: $focusedField,
                focusValue: .targetWeight,
                errorMessage: profileVM.fieldErrors["targetWeightKg"]
            )

            weeklyPaceSection

            targetDateSection
        }
        .padding(16)
        .appGlassSurface()
    }

    private var maintainPlanFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Maintenance range · optional")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            Text("If you set one limit, set both. The range must be 0.5–10 kg wide.")
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)

            AppTextField(
                title: "Lower weight (\(UnitConversion.bodyWeightUnitLabel(preferred: profileVM.preferredUnits)))",
                text: $profileVM.maintainWeightMin,
                keyboardType: .decimalPad,
                focus: $focusedField,
                focusValue: .maintainMinimum,
                errorMessage: profileVM.fieldErrors["targetWeightMinKg"]
            )

            AppTextField(
                title: "Upper weight (\(UnitConversion.bodyWeightUnitLabel(preferred: profileVM.preferredUnits)))",
                text: $profileVM.maintainWeightMax,
                keyboardType: .decimalPad,
                focus: $focusedField,
                focusValue: .maintainMaximum,
                errorMessage: profileVM.fieldErrors["targetWeightMaxKg"]
            )
        }
        .padding(16)
        .appGlassSurface()
    }

    private var targetDateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Set a target date · Optional", isOn: targetDateEnabled)
                .font(.subheadline.weight(.semibold))
                .tint(AppColors.accent)

            if targetDateEnabled.wrappedValue {
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .foregroundStyle(AppColors.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Target date")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text("At least two weeks from today")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()

                    Text(AppDate.displayFormatter("d MMM yyyy").string(from: selectedTargetDate.wrappedValue))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColors.accent)
                }
                .padding(12)
                .appGlassSurface(level: .inset)

                DatePicker(
                    "Target date",
                    selection: selectedTargetDate,
                    in: earliestTargetDate...,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.graphical)
                .tint(AppColors.accent)
                .padding(8)
                .appGlassSurface(level: .inset)

            }

            if let error = profileVM.fieldErrors["targetDate"] {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppColors.error)
            }
        }
    }

    private var weeklyPaceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly pace · Optional")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            Text("Choose a common pace or enter a custom value in kg per week.")
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    paceChoices
                }

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    alignment: .leading,
                    spacing: 10
                ) {
                    paceChoices
                }
            }

            AppTextField(
                title: "Custom pace (kg/week) · Optional",
                text: $profileVM.weeklyRateKg,
                keyboardType: .decimalPad,
                focus: $focusedField,
                focusValue: .weeklyPace,
                errorMessage: profileVM.fieldErrors["weeklyRateKg"]
            )
        }
    }

    @ViewBuilder
    private var paceChoices: some View {
        ForEach(["0.25", "0.5", "0.75"], id: \.self) { pace in
            SelectableChip(
                title: "\(pace) kg",
                isSelected: profileVM.weeklyRateKg == pace
            ) {
                profileVM.weeklyRateKg = pace
            }
        }
    }

    private var targetDateEnabled: Binding<Bool> {
        Binding(
            get: { !profileVM.targetDate.isEmpty },
            set: { isEnabled in
                profileVM.targetDate = isEnabled
                    ? AppDate.dateOnlyFormatter().string(from: earliestTargetDate)
                    : ""
            }
        )
    }

    private var selectedTargetDate: Binding<Date> {
        Binding(
            get: {
                AppDate.dateOnlyFormatter().date(from: profileVM.targetDate)
                    ?? earliestTargetDate
            },
            set: { date in
                profileVM.targetDate = AppDate.dateOnlyFormatter().string(from: date)
            }
        )
    }

    private var earliestTargetDate: Date {
        let today = Calendar.current.startOfDay(for: .now)
        return Calendar.current.date(byAdding: .day, value: 14, to: today) ?? today
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = profileVM.saveError {
            ErrorView(error: error, onRetry: save)
        } else if let error = goalsVM.saveError {
            ErrorView(error: error, onRetry: startNewCycle)
        }
    }

    private var saveButton: some View {
        PrimaryButton(title: profileVM.hasChangedGoalDirection ? "Review new cycle" : "Save plan") {
            save()
        }
        .disabled(isSaving || goalsVM.isUpdatingGoals)
    }

    private func select(_ goal: Goal) {
        guard profileVM.goal != goal else { return }

        let changesDirection = profileVM.goal != nil && profileVM.goal != goal
        profileVM.goal = goal
        profileVM.clearFieldError("goal")

        guard changesDirection else { return }

        // A new direction needs its own inputs; retaining a lose target while
        // switching to gain would create an invalid request.
        profileVM.targetWeight = ""
        profileVM.maintainWeightMin = ""
        profileVM.maintainWeightMax = ""
        profileVM.weeklyRateKg = ""
        profileVM.targetDate = ""
        [
            "targetWeightKg", "targetWeightMinKg", "targetWeightMaxKg",
            "weeklyRateKg", "targetDate"
        ].forEach(profileVM.clearFieldError)
    }

    private func directionDetail(for goal: Goal) -> String {
        switch goal {
        case .lose:
            "Choose a target below your current weight."
        case .gain:
            "Choose a target above your current weight."
        case .maintain:
            "Set a comfortable range around your current weight."
        }
    }

    private func save() {
        if profileVM.hasChangedGoalDirection {
            pendingNewCycle = profileVM.makeNewGoalCycleRequest()
            showNewCycleConfirmation = pendingNewCycle != nil
            return
        }

        Task {
            isSaving = true
            defer { isSaving = false }
            if await profileVM.saveGoalPlan() {
                dismiss()
            }
        }
    }

    private func startNewCycle() {
        guard let request = pendingNewCycle else { return }

        Task {
            isSaving = true
            defer { isSaving = false }
            if await goalsVM.startNewCycle(request) {
                await profileVM.loadData(forceRefresh: true)
                if case .loaded(let goals) = goalsVM.state {
                    startedCycleGoals = goals
                }
                pendingNewCycle = nil
            }
        }
    }
}
