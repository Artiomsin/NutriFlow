import SwiftUI

struct GoalsManagementView: View {
    private enum SaveAction {
        case manual
        case automatic
    }

    @Bindable var goalsVM: GoalsViewModel

    @State private var isSaving = false
    @State private var isResettingGoals = false
    @State private var successMessage: String?
    @State private var showResetConfirmation = false
    @State private var lastSaveAction: SaveAction?
    @State private var history: [GoalVersionEntry] = []
    @State private var historyNextCursor: String?
    @State private var isLoadingMoreHistory = false
    @State private var lastSeededGoals: UserGoals?

    @State private var calories = 2200.0
    @State private var protein = 150.0
    @State private var fat = 65.0
    @State private var carbs = 250.0
    @State private var water = 3000
    @State private var steps = 8000
    @State private var activeCalories = 500
    @State private var workouts = 5
    @State private var workoutMinutes = 155
    @State private var sleepMinMin = 240
    @State private var sleepMaxMin = 510

    private var currentGoals: UserGoals? {
        if case .loaded(let goals) = goalsVM.state { return goals }
        return nil
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                header

                if case .error(let error) = goalsVM.state {
                    ErrorView(error: error) { goalsVM.retryGoals() }
                }

                GoalPersonalizationSection(
                    state: goalsVM.personalizationState,
                    goals: currentGoals,
                    isProcessing: goalsVM.isProcessingPersonalization,
                    error: goalsVM.personalizationError,
                    onRetry: { goalsVM.retryPersonalization() },
                    onRequest: {
                        Task { await goalsVM.requestPersonalization() }
                    },
                    onAccept: { recommendation in
                        Task {
                            let accepted = await goalsVM.acceptRecommendation(recommendation)
                            if accepted {
                                seedDrafts()
                                await loadHistory(forceNetwork: true)
                            }
                        }
                    },
                    onDismiss: { recommendation in
                        Task { await goalsVM.dismissRecommendation(recommendation) }
                    }
                )

                nutritionSection
                activitySection
                sleepSection
                saveButton
                historySection
            }
            .padding(.horizontal, AppSpacing.paddingHorizontal)
            .padding(.bottom, 40)
        }
        .background(AppColors.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await goalsVM.loadPersonalization()
            await goalsVM.loadGoals()
            seedDrafts()
            await loadHistory()
        }
        .onChange(of: successMessage) { _, message in
            guard message != nil else { return }
            Task {
                try? await Task.sleep(for: .seconds(2))
                successMessage = nil
            }
        }
        .confirmationDialog(
            "Use automatic goals?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Switch to automatic goals") {
                Task { await resetToAutomaticGoals() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your manual or personalized targets will be replaced using your current profile and weight.")
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Goals")
                .font(AppTypography.heading1)
                .foregroundColor(AppColors.textPrimary)
                .padding(.top, AppSpacing.headerPaddingTop)
            Text("Manage your daily targets")
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)
            sourceBadge
        }
    }

    @ViewBuilder
    private var sourceBadge: some View {
        if let goals = currentGoals {
            Text(sourceLabel(goals.source))
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppColors.accent.opacity(0.12))
                .cornerRadius(AppRadius.chip)
        }
    }

    private var nutritionSection: some View {
        groupedSection(title: "Nutrition") {
            nutritionStepperRow(label: "Calories", caption: "per day", value: $calories, range: 1_000...5_000, step: 0.1, unit: UnitConversion.formatEnergyUnit(preferred: PreferencesStore.shared.preferredUnits), field: "dailyCaloriesGoal", errorMessage: goalsVM.fieldErrors["dailyCaloriesGoal"])
            divider
            nutritionStepperRow(label: "Protein", caption: "per day", value: $protein, range: 30...300, step: 0.1, unit: "g", field: "dailyProteinGoal", errorMessage: goalsVM.fieldErrors["dailyProteinGoal"])
            divider
            nutritionStepperRow(label: "Fat", caption: "per day", value: $fat, range: 20...200, step: 0.1, unit: "g", field: "dailyFatGoal", errorMessage: goalsVM.fieldErrors["dailyFatGoal"])
            divider
            nutritionStepperRow(label: "Carbs", caption: "per day", value: $carbs, range: 50...600, step: 0.1, unit: "g", field: "dailyCarbsGoal", errorMessage: goalsVM.fieldErrors["dailyCarbsGoal"])
            divider
            stepperRow(label: "Water", caption: "per day", value: $water, range: 500...6000, step: 100, unit: "ml", field: "dailyWaterGoal", errorMessage: goalsVM.fieldErrors["dailyWaterGoal"])
        }
    }

    private var activitySection: some View {
        groupedSection(title: "Activity") {
            stepperRow(label: "Steps", caption: "per day", value: $steps, range: 1000...30000, step: 500, unit: "steps", field: "dailyStepsGoal", errorMessage: goalsVM.fieldErrors["dailyStepsGoal"])
            divider
            stepperRow(label: "Active calories", caption: "per day", value: $activeCalories, range: 100...3000, step: 50, unit: UnitConversion.formatEnergyUnit(preferred: PreferencesStore.shared.preferredUnits), field: "dailyActiveCaloriesGoal", errorMessage: goalsVM.fieldErrors["dailyActiveCaloriesGoal"])
            divider
            stepperRow(label: "Workouts", caption: "per week", value: $workouts, range: 1...14, step: 1, unit: "", field: "weeklyWorkoutsGoal", errorMessage: goalsVM.fieldErrors["weeklyWorkoutsGoal"])
            divider
            stepperRow(label: "Workout minutes", caption: "per week", value: $workoutMinutes, range: 15...900, step: 15, unit: "min", field: "weeklyWorkoutMinutesGoal", errorMessage: goalsVM.fieldErrors["weeklyWorkoutMinutesGoal"])
        }
    }

    private var sleepSection: some View {
        groupedSection(title: "Sleep") {
            stepperRow(label: "Min sleep", caption: "per night", value: $sleepMinMin, range: 180...720, step: 30, unit: "min", field: "nightlySleepMinMinutes", errorMessage: goalsVM.fieldErrors["nightlySleepMinMinutes"])
            divider
            stepperRow(label: "Max sleep", caption: "per night", value: $sleepMaxMin, range: 360...960, step: 30, unit: "min", field: "nightlySleepMaxMinutes", errorMessage: goalsVM.fieldErrors["nightlySleepMaxMinutes"])
        }
    }

    private func groupedSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppColors.textTertiary )
                Spacer()
            }
            .padding(.leading, 2)

            VStack(spacing: 0) {
                content()
            }
            .appGlassSurface()
        }
    }

    private var divider: some View {
        Divider()
            .padding(.leading, AppSpacing.paddingHorizontal + 20)
            .opacity(0.3)
    }

    private static func roundNutrition(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    private func nutritionStepperRow(
        label: String,
        caption: String? = nil,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String,
        field: String,
        errorMessage: String?
    ) -> some View {
        let stepperValue = Binding(
            get: { value.wrappedValue },
            set: { newValue in
                value.wrappedValue = Self.roundNutrition(newValue)
                goalsVM.clearFieldError(field)
            }
        )

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Circle()
                    .fill(AppColors.accent.opacity(0.8))
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textPrimary)
                    if let caption {
                        Text(caption)
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                Spacer(minLength: 12)
                HStack(spacing: 4) {
                    TextField(
                        "",
                        text: Binding(
                            get: { value.wrappedValue.formatted(.number.precision(.fractionLength(0...1))) },
                            set: { newValue in
                                goalsVM.clearFieldError(field)
                                guard let parsed = UnitConversion.parseDecimal(newValue) else { return }
                                value.wrappedValue = Self.roundNutrition(parsed)
                            }
                        )
                    )
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(AppColors.textPrimary)
                    .tint(AppColors.accent)
                    .frame(width: 75)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(AppColors.surfaceSecondary)
                    .cornerRadius(6)

                    Text(unit)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
                Stepper("", value: stepperValue, in: range, step: step)
                    .labelsHidden()
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(AppColors.error)
            }
        }
        .padding(.horizontal, AppSpacing.paddingHorizontal)
        .padding(.vertical, 8)
    }

    private func stepperRow(
        label: String,
        caption: String? = nil,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        unit: String,
        field: String,
        errorMessage: String?
    ) -> some View {
        let stepperValue = Binding(
            get: { value.wrappedValue },
            set: { newValue in
                value.wrappedValue = newValue
                goalsVM.clearFieldError(field)
            }
        )

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
            Circle()
                .fill(AppColors.accent.opacity(0.8))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if let caption {
                    Text(caption)
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textTertiary )
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 12)
            HStack(spacing: 4) {
                TextField(
                    "",
                    text: Binding(
                        get: { String(value.wrappedValue) },
                        set: { newValue in
                            goalsVM.clearFieldError(field)
                            let filtered = newValue.filter { "0123456789".contains($0) }
                            if let intVal = Int(filtered) {
                                value.wrappedValue = intVal
                            } else if filtered.isEmpty {
                                value.wrappedValue = 0
                            }
                        }
                    )
                )
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(AppColors.textPrimary)
                .tint(AppColors.accent)
                .frame(width: 75)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(AppColors.surfaceSecondary)
                .cornerRadius(6)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            Stepper(
                "",
                value: stepperValue,
                in: range,
                step: step
            )
            .labelsHidden()
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(AppColors.error)
            }
        }
        .padding(.horizontal, AppSpacing.paddingHorizontal)
        .padding(.vertical, 8)
    }

    private var saveButton: some View {
        VStack(spacing: 10) {
            if let saveError = goalsVM.saveError {
                ErrorView(error: saveError, onRetry: retryLastSaveAction)
            }
            Button {
                Task { await save() }
            } label: {
                if isSaving {
                    ProgressView()
                        .tint(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                } else {
                    Text(successMessage ?? "Save goals")
                        .font(.headline)
                        .foregroundColor(AppColors.accentOnPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
            }
            .background(successMessage != nil ? AppColors.accent.opacity(0.7) : AppColors.accent)
            .cornerRadius(AppRadius.medium)
            .disabled(isSaving)

            automaticGoalsControl
        }
    }

    @ViewBuilder
    private var automaticGoalsControl: some View {
        if let goals = currentGoals, goals.source == "user" {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.accent)
                        .frame(width: 30, height: 30)
                        .background(AppColors.accent.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Automatic calculation is off")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text("Your manual targets stay fixed when your weight changes.")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                Button {
                    showResetConfirmation = true
                } label: {
                    HStack {
                        if isResettingGoals {
                            ProgressView()
                                .tint(AppColors.accent)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isResettingGoals ? "Calculating…" : "Switch to automatic goals")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppColors.accent.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                }
                .disabled(isSaving || isResettingGoals)
            }
            .padding(12)
            .appGlassSurface()
        } else if currentGoals?.source == "personalized" {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.accent)
                        .frame(width: 30, height: 30)
                        .background(AppColors.accent.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Personalized plan")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text("Recommendation adjustments are kept while goals adapt to your profile and weight.")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                Button("Use standard automatic goals") {
                    showResetConfirmation = true
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColors.accent)
                .disabled(isSaving || isResettingGoals)
            }
            .padding(12)
            .appGlassSurface()
        }
    }

    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Goal Activity")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Track how your daily targets change over time")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.textTertiary)
                }

                Spacer()

                if !history.isEmpty {
                    Text("\(history.count) versions")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            if let historyError = goalsVM.historyError {
                ErrorView(error: historyError) {
                    Task {
                        await loadHistory(forceNetwork: true)
                    }
                }
            } else if history.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 24))
                        .foregroundStyle(AppColors.textTertiary)

                    Text("No goal changes yet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)

                    Text("Your goal history will appear here after your first update.")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 16)
                .appGlassSurface()
            } else {
                GoalHistoryTimeline(entries: history)

                if historyNextCursor != nil {
                    Button {
                        Task {
                            await loadMoreHistory()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isLoadingMoreHistory {
                                ProgressView()
                                    .tint(AppColors.accent)
                            } else {
                                Text("Load older changes")

                                Image(systemName: "arrow.down")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingMoreHistory)
                }
            }
        }
    }


    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        lastSaveAction = .manual
        defer { isSaving = false }

        let success = await goalsVM.updateGoals(
            calories: calories,
            protein: protein,
            fat: fat,
            carbs: carbs,
            water: water,
            steps: steps,
            activeCalories: activeCalories,
            workouts: workouts,
            workoutMinutes: workoutMinutes,
            sleepMinMinutes: sleepMinMin,
            sleepMaxMinutes: sleepMaxMin
        )
        if success {
            successMessage = "Goals saved"
            await loadHistory(forceNetwork: true)
        }
    }

    private func resetToAutomaticGoals() async {
        guard !isResettingGoals else { return }
        isResettingGoals = true
        lastSaveAction = .automatic
        defer { isResettingGoals = false }

        if await goalsVM.resetGoalsToAutomatic() {
            seedDrafts()
            successMessage = "Automatic goals enabled"
            await loadHistory(forceNetwork: true)
        }
    }

    private func retryLastSaveAction() {
        Task {
            switch lastSaveAction {
            case .automatic:
                await resetToAutomaticGoals()
            case .manual, .none:
                await save()
            }
        }
    }

    private func seedDrafts() {
        guard let goals = currentGoals, goals != lastSeededGoals else { return }
        lastSeededGoals = goals
        calories = goals.dailyCaloriesGoal ?? calories
        protein = goals.dailyProteinGoal ?? protein
        fat = goals.dailyFatGoal ?? fat
        carbs = goals.dailyCarbsGoal ?? carbs
        water = goals.dailyWaterGoal ?? water
        steps = goals.dailyStepsGoal ?? steps
        activeCalories = goals.dailyActiveCaloriesGoal ?? activeCalories
        workouts = goals.weeklyWorkoutsGoal ?? workouts
        workoutMinutes = goals.weeklyWorkoutMinutesGoal ?? workoutMinutes
        sleepMinMin = goals.nightlySleepMinMinutes ?? sleepMinMin
        sleepMaxMin = goals.nightlySleepMaxMinutes ?? sleepMaxMin
    }

    private func loadHistory(forceNetwork: Bool = false) async {
        guard let page = await goalsVM.loadGoalHistory(forceNetwork: forceNetwork) else {
            return
        }
        history = page.items
        historyNextCursor = page.nextCursor
    }

    private func loadMoreHistory() async {
        guard let cursor = historyNextCursor, !isLoadingMoreHistory else { return }
        isLoadingMoreHistory = true
        defer { isLoadingMoreHistory = false }

        guard let page = await goalsVM.loadGoalHistory(cursor: cursor) else { return }
        let known = Set(history.map(\.id))
        history.append(contentsOf: page.items.filter { !known.contains($0.id) })
        historyNextCursor = page.nextCursor
    }

    private func sourceLabel(_ source: String?) -> String {
        switch source?.lowercased() {
        case "initial": return "Automatic"
        case "user": return "Manual"
        case "personalized": return "Personalized"
        default: return "Auto"
        }
    }
}

#Preview("Goals Management") {
    let coordinator = AppCoordinator(container: AppDependencyContainer())
    let goalsVM = GoalsViewModel(coordinator: coordinator, service: MockGoalsService())
    goalsVM.state = .loaded(UserGoals(
        id: "mock", userId: "mock",
        dailyCaloriesGoal: 2200, dailyProteinGoal: 150,
        dailyFatGoal: 65, dailyCarbsGoal: 250, dailyWaterGoal: 3000,
        dailyStepsGoal: 8000, dailyActiveCaloriesGoal: 500,
        weeklyWorkoutsGoal: 5, weeklyWorkoutMinutesGoal: 155,
        nightlySleepMinMinutes: 234, nightlySleepMaxMinutes: 500,
        source: "personalized", createdAt: nil, updatedAt: nil
    ))
    return NavigationStack {
        GoalsManagementView(goalsVM: goalsVM)
    }
    .background(AppColors.background)
    
}
