import SwiftUI

struct ProgressDashboardView: View {
    @Bindable var analyticsVM: AnalyticsViewModel
    @Bindable var chartVM: ProgressChartViewModel
    @Bindable var goalsVM: GoalsViewModel
    @Bindable var periodState: PeriodState
    var tabBarState: TabBarState = TabBarState()

    let progressRefreshState: ProgressRefreshState
    let isActive: Bool

    @State private var prefsStore = PreferencesStore.shared
    @State private var hasLoadedProgress = false
    @State private var isInitialProgressLoading = false
    @State private var showWeightEntry = false
    @State private var weightInput = ""
    @State private var weightEntryError: AppError?
    @State private var isRecordingWeight = false
    @State private var showWeightHistory = false
    @State private var pendingWeightDeletion: WeightLog?
    @State private var isDeletingWeight = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                header

                PeriodSelectorView(
                    selectedPeriod: periodState.type,
                    fromDate: periodState.fromDate,
                    toDate: periodState.toDate,
                    onPeriodChange: {
                        analyticsVM.setPeriod($0)
                        chartVM.setPeriod($0)
                    },
                    onCustomRange: { from, to in
                        analyticsVM.setCustomRange(from: from, to: to)
                        chartVM.setCustomRange(from: from, to: to)
                    }
                )
                analyticsContent
                weightCard
                chartsContent
                Spacer(minLength: 100)
            }
            .padding(.horizontal, AppSpacing.paddingHorizontal)
        }
        .minimizeTabBarOnScroll(
            tabBarState: tabBarState
        )
        .refreshable {
            let task = Task {
                async let analytics: () = analyticsVM.refreshData()
                async let charts: () = chartVM.refreshData()
                async let goals: () = goalsVM.loadGoals()
                async let weight: () = chartVM.loadWeightSummary()
                (_, _, _, _) = await (analytics, charts, goals, weight)
            }
            await task.value
        }
        .onAppear {
            loadInitialIfNeeded()
        }
        .onChange(of: isActive) { _, active in
            guard active else { return }
            if hasLoadedProgress {
                let revision = progressRefreshState.revision
                Task {
                    async let analytics: () = analyticsVM.refreshIfNeeded(currentRevision: revision)
                    async let charts: () = chartVM.refreshIfNeeded(currentRevision: revision)
                    (_, _) = await (analytics, charts)
                }
            } else {
                loadInitialIfNeeded()
            }
        }
        .sheet(isPresented: $chartVM.showDaySheet) {
            DayDetailSheet(
                dateStr: chartVM.selectedDateStr,
                food: chartVM.selectedDateFood,
                water: chartVM.selectedDateWater,
                goals: chartVM.selectedDateGoals,
                state: chartVM.dayDetailState,
                activity: chartVM.selectedDateActivity,
                workouts: chartVM.selectedDateWorkouts,
                warning: chartVM.dayDetailWarning,
                onRetry: { Task { await chartVM.loadDayDetail(date: chartVM.selectedDateStr) } }
            )
        }
        .sheet(isPresented: $showWeightEntry) {
            WeightEntrySheet(
                weightInput: $weightInput,
                error: $weightEntryError,
                isSaving: isRecordingWeight,
                latestWeightKg: chartVM.weightLatestKg,
                preferredUnits: prefsStore.preferredUnits,
                onSave: recordWeight
            )
        }
        .sheet(isPresented: $showWeightHistory) {
            weightHistorySheet
        }
    }

    @MainActor
    private func loadInitialIfNeeded() {
        guard isActive, !hasLoadedProgress, !isInitialProgressLoading else {
            return
        }

        isInitialProgressLoading = true
        let revision = progressRefreshState.revision

        Task {
            defer {
                isInitialProgressLoading = false
            }

            async let analytics: () = analyticsVM.loadAnalytics()
            async let charts: () = chartVM.loadChartData()
            async let goals: () = goalsVM.loadGoals()
            async let weight: () = chartVM.loadWeightSummary()
            (_, _, _, _) = await (analytics, charts, goals, weight)

            var didLoadDashboard = false

            switch analyticsVM.state {
            case .loaded, .empty:
                analyticsVM.markRevisionAsCurrent(revision)
                didLoadDashboard = true
            default:
                break
            }

            if case .loaded = chartVM.chartState {
                chartVM.markRevisionAsCurrent(revision)
                didLoadDashboard = true
            }

            hasLoadedProgress = didLoadDashboard
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Progress")
                .font(AppTypography.heading1)
                .foregroundColor(AppColors.textPrimary)
                .padding(.top, AppSpacing.headerPaddingTop)
            Text("Your nutrition trends")
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    @ViewBuilder
    private var analyticsContent: some View {
        switch analyticsVM.state {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.vertical, 40)
        case .loaded(let analytics):
            VStack(spacing: 20) {
                AnalyticsHeroView(streak: analytics.streak, trend: analytics.trend)

                ringsGrid(analytics: analytics)

                AnalyticsStatsView(
                    avgCalories: analytics.averageCalories,
                    avgProtein: analytics.averageProtein,
                    avgFat: analytics.averageFat,
                    avgCarbs: analytics.averageCarbs,
                    avgWater: analytics.averageWater,
                    daysTracked: analytics.daysTracked,
                    totalDays: analytics.totalDays
                )
            }
        case .empty:
            emptyState
        case .error(let error):
            ErrorView(error: error) {
                Task { await analyticsVM.refreshData() }
            }
        }
    }

    private var weightCard: some View {
        VStack(spacing: 8) {
            if let weightError = chartVM.weightError {
                ErrorView(error: weightError) {
                    Task { await chartVM.loadWeightSummary() }
                }
            }
            WeightCardView(
                points: chartVM.weightPoints,
                latestKg: chartVM.weightLatestKg,
                deltaKg: chartVM.weightDeltaKg,
                weeklyRateKg: chartVM.weightWeeklyRateKg,
                periodLabel: chartVM.weightPeriodLabel,
                onRecordWeight: {
                    weightInput = ""
                    weightEntryError = nil
                    showWeightEntry = true
                },
                onManageWeights: {
                    chartVM.weightHistoryError = nil
                    showWeightHistory = true
                }
            )
        }
    }

    private func recordWeight() {
        guard let displayWeight = UnitConversion.parseDecimal(weightInput) else {
            weightEntryError = .validation(message: "Enter a valid weight.")
            return
        }

        let weightKg = UnitConversion.bodyWeightToKg(
            displayWeight,
            preferred: prefsStore.preferredUnits
        )
        guard (20...400).contains(weightKg) else {
            weightEntryError = .validation(message: "Enter a weight between 20 and 400 kg.")
            return
        }

        isRecordingWeight = true
        weightEntryError = nil
        Task {
            defer { isRecordingWeight = false }
            do {
                try await chartVM.recordCurrentWeight(weightKg)
                async let analytics: () = analyticsVM.refreshData()
                async let goals: () = goalsVM.loadGoals()
                (_, _) = await (analytics, goals)
                showWeightEntry = false
            } catch {
                weightEntryError = ErrorMapper.map(error)
            }
        }
    }

    private var weightHistorySheet: some View {
        NavigationStack {
            List {
                if let weightHistoryError = chartVM.weightHistoryError {
                    ErrorView(error: weightHistoryError) {
                        Task { await chartVM.loadWeightHistory() }
                    }
                }

                ForEach(chartVM.weightEntries.reversed()) { entry in
                    HStack {
                        Image(systemName: entry.source == "initial" ? "flag.fill" : "scalemass.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(entry.source == "initial" ? AppColors.textSecondary : AppColors.accent)
                            .frame(width: 30, height: 30)
                            .background((entry.source == "initial" ? AppColors.textSecondary : AppColors.accent).opacity(0.12))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text(formattedWeightDate(entry.entryDate))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppColors.textPrimary)
                            Text(entry.source == "initial" ? "Initial weight" : "Manual record")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        let displayWeight = UnitConversion.bodyWeightToDisplay(
                            kg: entry.weightKg,
                            preferred: prefsStore.preferredUnits
                        )
                        Text("\(displayWeight.formatted(.number.precision(.fractionLength(0...1)))) \(UnitConversion.bodyWeightUnitLabel(preferred: prefsStore.preferredUnits))")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundColor(AppColors.textPrimary)

                        if entry.source != "initial" {
                            Button(role: .destructive) {
                                pendingWeightDeletion = entry
                            } label: {
                                Image(systemName: "trash")
                            }
                            .disabled(isDeletingWeight)
                            .accessibilityLabel("Delete weight record")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("Weight records")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showWeightHistory = false }
                }
            }
            .task {
                await chartVM.loadWeightHistory()
            }
            .confirmationDialog(
                "Delete this weight record?",
                isPresented: Binding(
                    get: { pendingWeightDeletion != nil },
                    set: { if !$0 { pendingWeightDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteSelectedWeight()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("The chart and automatic goals will be updated if this is today’s current record.")
            }
        }
    }

    private func deleteSelectedWeight() {
        guard let entry = pendingWeightDeletion else { return }
        isDeletingWeight = true
        Task {
            defer {
                isDeletingWeight = false
                pendingWeightDeletion = nil
            }
            do {
                try await chartVM.deleteWeightEntry(date: entry.entryDate)
                async let analytics: () = analyticsVM.refreshData()
                async let goals: () = goalsVM.loadGoals()
                (_, _) = await (analytics, goals)
            } catch {
                chartVM.weightHistoryError = ErrorMapper.map(error)
            }
        }
    }

    private func formattedWeightDate(_ value: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: String(value.prefix(10))) else { return value }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    @ViewBuilder
    private var chartsContent: some View {
        switch chartVM.chartState {
        case .idle, .loading:
            ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.vertical, 20)
        case .loaded(let data):
            ZStack {
                if hasChartData(data) {
                    VStack(spacing: 20) {
                        if let firstCalories = data.first(where: { $0.calories > 0 }) {
                            CaloriesChartView(data: data, canTap: chartVM.canTapBars, onBarTap: { chartVM.handleBarTap(point: $0) }, initialScrollX: initialScrollLabel(in: data, firstDataPoint: firstCalories))
                        }

                        if let firstWater = data.first(where: { $0.waterMl > 0 }) {
                            WaterChartView(data: data, canTap: chartVM.canTapBars, onBarTap: { chartVM.handleBarTap(point: $0) }, initialScrollX: initialScrollLabel(in: data, firstDataPoint: firstWater))
                        }

                        if let firstMacros = data.first(where: { $0.protein > 0 || $0.fat > 0 || $0.carbs > 0 }) {
                            NutritionChartView(data: data, canTap: chartVM.canTapBars, onBarTap: { chartVM.handleBarTap(point: $0) }, initialScrollX: initialScrollLabel(in: data, firstDataPoint: firstMacros))
                        }

                        if let firstActivity = data.first(where: { $0.calories > 0 || $0.activeCalories > 0 || $0.basalCalories > 0 }) {
                            ActivityChartView(data: data, canTap: chartVM.canTapBars, onBarTap: { chartVM.handleBarTap(point: $0) }, initialScrollX: initialScrollLabel(in: data, firstDataPoint: firstActivity))
                        }
                    }
                } else if case .empty = analyticsVM.state {
                    EmptyView()
                } else {
                    emptyState
                }
            }
            .overlay {
                if chartVM.isPeriodLoading {
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(AppColors.background.opacity(0.55))
                        .overlay {
                            ProgressView()
                                .tint(AppColors.accent)
                        }
                }
            }
            .allowsHitTesting(!chartVM.isPeriodLoading)
        case .error(let error):
            ErrorView(error: error) {
                Task { await chartVM.refreshData() }
            }
        }
    }

    private func hasChartData(_ data: [ChartDataPoint]) -> Bool {
        data.contains {
            $0.calories > 0 ||
            $0.waterMl > 0 ||
            $0.protein > 0 ||
            $0.fat > 0 ||
            $0.carbs > 0 ||
            $0.activeCalories > 0 ||
            $0.basalCalories > 0
        }
    }

    private func initialScrollLabel(in data: [ChartDataPoint], firstDataPoint: ChartDataPoint) -> String {
        firstDataPoint.label
    }

private struct RingItem: Identifiable {
        let id = UUID()
        let icon: String
        let color: Color
        let title: String
        let pct: Int
    }

    @ViewBuilder
    private func ringsGrid(analytics: AnalyticsResponse) -> some View {
        let fitnessRows = goalsVM.fitnessGoalRows(
            avgSteps: Double(analytics.avgSteps ?? 0),
            avgActiveCalories: Double(analytics.avgActiveCalories ?? 0),
            sleepNightsInRange: analytics.sleepNightsInRange ?? 0,
            sleepTotalNights: analytics.sleepTotalNights ?? 0,
            workoutsDone: analytics.workoutsDone ?? 0,
            workoutMinutes: analytics.workoutMinutes ?? 0,
            daysCount: chartVM.periodDays
        ).filter(\.show)

        let nutrition: [RingItem] = [
            RingItem(icon: "flame.fill", color: .orange, title: "Calories", pct: analytics.goalCaloriesPct ?? 0),
            RingItem(icon: "bolt.fill", color: .indigo, title: "Protein", pct: analytics.goalProteinPct ?? 0),
            RingItem(icon: "drop.degreesign.fill", color: .green, title: "Fat", pct: analytics.goalFatPct ?? 0),
            RingItem(icon: "leaf.arrow.circlepath", color: .purple, title: "Carbs", pct: analytics.goalCarbsPct ?? 0),
            RingItem(icon: "drop.fill", color: .cyan, title: "Water", pct: analytics.goalWaterPct ?? 0)
        ]

        let items = fitnessRows.map { row in
            RingItem(
                icon: row.kind.icon,
                color: row.kind.color,
                title: row.kind.title,
                pct: row.percent
            )
        } + nutrition

        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
            spacing: 14
        ) {
            ForEach(items) { item in
                RingProgressView(
                    pct: item.pct,
                    color: item.color,
                    icon: item.icon,
                    title: item.title,
                    value: "",
                    unit: "",
                    compact: true
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(AppTypography.displayNumber)
                .foregroundColor(AppColors.textSecondary)
            Text("No data for this period")
                .font(.headline)
                .foregroundColor(AppColors.textSecondary)
            Text("Start tracking to see statistics")
                .font(.subheadline)
                .foregroundColor(AppColors.textTertiary )
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}

private struct WeightEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var weightInput: String
    @Binding var error: AppError?

    let isSaving: Bool
    let latestWeightKg: Double?
    let preferredUnits: PreferredUnits
    let onSave: () -> Void

    @FocusState private var isWeightFieldFocused: Bool

    private var unit: String {
        UnitConversion.bodyWeightUnitLabel(preferred: preferredUnits)
    }

    private var lastWeightText: String? {
        guard let latestWeightKg else { return nil }
        let value = UnitConversion.bodyWeightToDisplay(kg: latestWeightKg, preferred: preferredUnits)
        return "\(value.formatted(.number.precision(.fractionLength(0...1)))) \(unit)"
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Record weight", systemImage: "scalemass.fill")
                        .font(.title3.weight(.bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("This updates today’s point. Automatic goals will use the new current weight.")
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("TODAY’S WEIGHT")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.textTertiary)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        TextField("0", text: $weightInput)
                            .focused($isWeightFieldFocused)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.leading)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(AppColors.textPrimary)
                            .tint(AppColors.accent)

                        Text(unit)
                            .font(.title3.weight(.semibold))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(AppColors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                }

                if let lastWeightText {
                    Label("Last recorded: \(lastWeightText)", systemImage: "clock.arrow.circlepath")
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                }

                if let error {
                    ErrorView(error: error)
                }

                Spacer(minLength: 0)

                Button(action: onSave) {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView().tint(AppColors.accentOnPrimary)
                        } else {
                            Image(systemName: "checkmark")
                        }
                        Text(isSaving ? "Saving…" : "Save today’s weight")
                    }
                    .font(.headline)
                    .foregroundColor(AppColors.accentOnPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(AppColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                }
                .disabled(isSaving || weightInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(isSaving || weightInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
            }
            .padding(AppSpacing.paddingHorizontal)
            .background(AppColors.background)
            .navigationTitle("Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                isWeightFieldFocused = true
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview("NutriFlow Progress") {
    ProgressPreviewContent()
}

private struct ProgressPreviewContent: View {
    var body: some View {
        let data = makePreviewData()
        return ProgressDashboardView(
                analyticsVM: data.analytics,
                chartVM: data.chart,
                goalsVM: data.goals,
                periodState: data.period,
                progressRefreshState: ProgressRefreshState(),
                isActive: true
            )
            .background(AppColors.background)
    }

    private func makePreviewData() -> (analytics: AnalyticsViewModel, chart: ProgressChartViewModel, goals: GoalsViewModel, period: PeriodState) {
        let periodState = PeriodState()
        periodState.type = .week
        let coordinator = AppCoordinator(container: AppDependencyContainer())
        let analyticsVM = AnalyticsViewModel(
            coordinator: coordinator,
            service: MockAnalyticsService(),
            periodState: periodState
        )
        let chartVM = ProgressChartViewModel(
            coordinator: coordinator,
            service: MockDailySummaryService(),
            periodState: periodState,
            foodService: MockFoodService(),
            waterService: MockWaterService(),
            goalsService: MockGoalsService(),
            activityService: MockActivityService(),
            profileService: MockProfileService(),
            workoutService: MockWorkoutService()
        )
        let goalsVM = GoalsViewModel(
            coordinator: coordinator,
            service: MockGoalsService()
        )

        goalsVM.state = .loaded(UserGoals(
            id: "mock",
            userId: "mock",
            dailyCaloriesGoal: 2000,
            dailyProteinGoal: 120,
            dailyFatGoal: 70,
            dailyCarbsGoal: 220,
            dailyWaterGoal: 2000,
            dailyStepsGoal: 10000,
            dailyActiveCaloriesGoal: 500,
weeklyWorkoutsGoal: 5,
            weeklyWorkoutMinutesGoal: 150,
            nightlySleepMinMinutes: 360,
            nightlySleepMaxMinutes: 600,
            source: "mock",
            createdAt: nil,
            updatedAt: nil
        ))

        return (analyticsVM, chartVM, goalsVM, periodState)
    }
}

extension FitnessGoalKind {
    var title: String {
        switch self {
        case .steps: return "Steps"
        case .activeCalories: return "Active kcal"
        case .sleep: return "Sleep"
        case .workouts: return "Workouts"
        case .workoutMinutes: return "Workout min"
        }
    }

    var icon: String {
        switch self {
        case .steps: return "figure.walk"
        case .activeCalories: return "flame.fill"
        case .sleep: return "moon.zzz.fill"
        case .workouts: return "dumbbell.fill"
        case .workoutMinutes: return "clock.fill"
        }
    }

    var color: Color {
        switch self {
        case .steps: return .blue
        case .activeCalories: return .pink
        case .sleep: return .teal
        case .workouts: return .green
        case .workoutMinutes: return .mint
        }
    }
}
