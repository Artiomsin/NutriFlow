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
            .padding(.horizontal, AppTheme.paddingHorizontal)
            .padding(.bottom, 40)
        }
        .background(AppTheme.background)
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
                .font(Font.h1)
                .foregroundColor(AppTheme.textPrimary)
                .padding(.top, AppTheme.headerPaddingTop)
            Text("Manage your daily targets")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
            sourceBadge
        }
    }

    @ViewBuilder
    private var sourceBadge: some View {
        if let goals = currentGoals {
            Text(sourceLabel(goals.source))
                .font(.caption.weight(.semibold))
                .foregroundColor(AppTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.accent.opacity(0.12))
                .cornerRadius(AppTheme.chipCornerRadius)
        }
    }

    private var nutritionSection: some View {
        groupedSection(title: "Nutrition") {
            stepperRow(label: "Calories", value: $calories, range: 1000...5000, step: 50, unit: UnitConversion.formatEnergyUnit(preferred: PreferencesStore.shared.preferredUnits))
            divider
            stepperRow(label: "Protein", value: $protein, range: 30...300, step: 5, unit: "g")
            divider
            stepperRow(label: "Fat", value: $fat, range: 20...200, step: 5, unit: "g")
            divider
            stepperRow(label: "Carbs", value: $carbs, range: 50...600, step: 5, unit: "g")
            divider
            stepperRow(label: "Water", value: $water, range: 500...6000, step: 100, unit: "ml")
        }
    }

    private var activitySection: some View {
        groupedSection(title: "Activity") {
            stepperRow(label: "Steps", value: $steps, range: 1000...30000, step: 500, unit: "steps")
            divider
            stepperRow(label: "Active calories", value: $activeCalories, range: 100...3000, step: 50, unit: UnitConversion.formatEnergyUnit(preferred: PreferencesStore.shared.preferredUnits))
            divider
            stepperRow(label: "Workouts / week", value: $workouts, range: 1...14, step: 1, unit: "")
            divider
            stepperRow(label: "Workout minutes / week", value: $workoutMinutes, range: 15...900, step: 15, unit: "min")
        }
    }

    private var sleepSection: some View {
        groupedSection(title: "Sleep") {
            stepperRow(label: "Sleep min / night", value: $sleepMinMin, range: 180...720, step: 30, unit: "min")
            divider
            stepperRow(label: "Sleep max / night", value: $sleepMaxMin, range: 360...960, step: 30, unit: "min")
        }
    }

    private func groupedSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppTheme.textTertiary)
                Spacer()
            }
            .padding(.leading, 2)

            VStack(spacing: 0) {
                content()
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        }
    }

    private var divider: some View {
        Divider()
            .padding(.leading, 52)
            .opacity(0.3)
    }

    private func stepperRow(label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppTheme.accent.opacity(0.8))
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
            Text("\(value.wrappedValue.formatted()) \(unit)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .frame(minWidth: 90, alignment: .trailing)
            Stepper(
                "",
                value: value,
                in: range,
                step: step
            )
            .labelsHidden()
        }
        .padding(.horizontal, AppTheme.paddingHorizontal)
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
                    .foregroundColor(AppTheme.primaryButtonText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
        }
        .background(showSaved ? AppTheme.accent.opacity(0.7) : AppTheme.accent)
        .cornerRadius(AppTheme.cornerRadiusMedium)
        .disabled(isSaving)
    }

    private var historySection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("History")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppTheme.textTertiary)
                Spacer()
            }
            .padding(.leading, 2)

            if history.isEmpty {
                Text("No changes yet")
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.cardBackground)
                    .cornerRadius(AppTheme.cornerRadiusMedium)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(history.prefix(20).enumerated()), id: \.element.id) { index, entry in
                        historyRow(entry)
                        if index < min(history.count, 20) - 1 {
                            divider
                        }
                    }
                }
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            }
        }
    }

    private func historyRow(_ entry: GoalHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(metricLabel(entry.metric))
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text(shortDate(entry.createdAt))
                    .font(.caption)
                    .foregroundColor(AppTheme.textTertiary)
            }
            HStack(spacing: 6) {
                Text(valueText(entry))
                    .font(.footnote)
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Text(sourceLabel(entry.source))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppTheme.accent)
            }
            if let reason = entry.reason, !reason.isEmpty {
                Text(reason)
                    .font(.caption2)
                    .foregroundColor(AppTheme.textTertiary)
            }
        }
        .padding(.horizontal, AppTheme.paddingHorizontal)
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
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}