import SwiftUI

struct GoalsManagementView: View {
    @Bindable var goalsVM: GoalsViewModel

    @State private var isSaving = false
    @State private var showSaved = false
    @State private var history: [GoalHistoryEntry] = []
    @State private var didSeed = false

    @State private var calories = 2200
    @State private var protein = 150
    @State private var fat = 65
    @State private var carbs = 250
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

                GoalPersonalizationSection(
                    state: goalsVM.personalizationState,
                    goals: currentGoals,
                    isProcessing: goalsVM.isProcessingPersonalization,
                    onRequest: {
                        Task { await goalsVM.requestPersonalization() }
                    },
                    onAccept: { recommendation in
                        Task {
                            await goalsVM.acceptRecommendation(recommendation)
                            seedDrafts()
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
        .onChange(of: showSaved) { _, visible in
            guard visible else { return }
            Task {
                try? await Task.sleep(for: .seconds(2))
                showSaved = false
            }
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
            stepperRow(label: "Calories", caption: "per day", value: $calories, range: 1000...5000, step: 50, unit: UnitConversion.formatEnergyUnit(preferred: PreferencesStore.shared.preferredUnits))
            divider
            stepperRow(label: "Protein", caption: "per day", value: $protein, range: 30...300, step: 5, unit: "g")
            divider
            stepperRow(label: "Fat", caption: "per day", value: $fat, range: 20...200, step: 5, unit: "g")
            divider
            stepperRow(label: "Carbs", caption: "per day", value: $carbs, range: 50...600, step: 5, unit: "g")
            divider
            stepperRow(label: "Water", caption: "per day", value: $water, range: 500...6000, step: 100, unit: "ml")
        }
    }

    private var activitySection: some View {
        groupedSection(title: "Activity") {
            stepperRow(label: "Steps", caption: "per day", value: $steps, range: 1000...30000, step: 500, unit: "steps")
            divider
            stepperRow(label: "Active calories", caption: "per day", value: $activeCalories, range: 100...3000, step: 50, unit: UnitConversion.formatEnergyUnit(preferred: PreferencesStore.shared.preferredUnits))
            divider
            stepperRow(label: "Workouts", caption: "per week", value: $workouts, range: 1...14, step: 1, unit: "")
            divider
            stepperRow(label: "Workout minutes", caption: "per week", value: $workoutMinutes, range: 15...900, step: 15, unit: "min")
        }
    }

    private var sleepSection: some View {
        groupedSection(title: "Sleep") {
            stepperRow(label: "Min sleep", caption: "per night", value: $sleepMinMin, range: 180...720, step: 30, unit: "min")
            divider
            stepperRow(label: "Max sleep", caption: "per night", value: $sleepMaxMin, range: 360...960, step: 30, unit: "min")
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
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        }
    }

    private var divider: some View {
        Divider()
            .padding(.leading, AppSpacing.paddingHorizontal + 20)
            .opacity(0.3)
    }

    private func stepperRow(
        label: String,
        caption: String? = nil,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        unit: String
    ) -> some View {
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
                value: value,
                in: range,
                step: step
            )
            .labelsHidden()
        }
        .padding(.horizontal, AppSpacing.paddingHorizontal)
        .padding(.vertical, 8)
    }

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            if isSaving {
                ProgressView()
                    .tint(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            } else {
                Text(showSaved ? "Saved" : "Save goals")
                    .font(.headline)
                    .foregroundColor(AppColors.accentOnPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
        }
        .background(showSaved ? AppColors.accent.opacity(0.7) : AppColors.accent)
        .cornerRadius(AppRadius.medium)
        .disabled(isSaving)
    }

    private var historySection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("History")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppColors.textTertiary )
                Spacer()
            }
            .padding(.leading, 2)

            if history.isEmpty {
                Text("No changes yet")
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.surface)
                    .cornerRadius(AppRadius.medium)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(history.prefix(20).enumerated()), id: \.element.id) { index, entry in
                        historyRow(entry)
                        if index < min(history.count, 20) - 1 {
                            divider
                        }
                    }
                }
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            }
        }
    }

    private func historyRow(_ entry: GoalHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(metricLabel(entry.metric))
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text(shortDate(entry.createdAt))
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary )
            }
            HStack(spacing: 6) {
                Text(valueText(entry))
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text(sourceLabel(entry.source))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.accent)
            }
            if let reason = entry.reason, !reason.isEmpty {
                Text(reason)
                    .font(.caption2)
                    .foregroundColor(AppColors.textTertiary )
            }
        }
        .padding(.horizontal, AppSpacing.paddingHorizontal)
        .padding(.vertical, 10)
    }

    private func valueText(_ entry: GoalHistoryEntry) -> String {
        let from = entry.oldValue.map(String.init) ?? "—"
        let to = entry.newValue.map(String.init) ?? "—"
        return "\(from) → \(to)"
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
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
            showSaved = true
            await loadHistory()
        }
    }

    private func seedDrafts() {
        guard !didSeed, let goals = currentGoals else { return }
        didSeed = true
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

    private func loadHistory() async {
        history = await goalsVM.loadGoalHistory()
    }

    private func sourceLabel(_ source: String?) -> String {
        switch source?.lowercased() {
        case "initial": return "Initial"
        case "user": return "Manual"
        case "personalized": return "Personalized"
        default: return "Auto"
        }
    }

    private func metricLabel(_ metric: String) -> String {
        switch metric {
        case "dailyCaloriesGoal": return "Calories"
        case "dailyProteinGoal": return "Protein"
        case "dailyFatGoal": return "Fat"
        case "dailyCarbsGoal": return "Carbs"
        case "dailyWaterGoal": return "Water"
        case "dailyStepsGoal": return "Steps"
        case "dailyActiveCaloriesGoal": return "Active calories"
        case "weeklyWorkoutsGoal": return "Workouts / week"
        case "weeklyWorkoutMinutesGoal": return "Workout minutes / week"
        case "nightlySleepMinMinutes": return "Sleep min / night"
        case "nightlySleepMaxMinutes": return "Sleep max / night"
        default: return metric
        }
    }

    private func shortDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: iso)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: iso)
        }
        guard let date else { return String(iso.prefix(10)) }
        return date.formatted(.dateTime.day().month(.abbreviated))
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
