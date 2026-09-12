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

    var body: some View {
        let _ = print("ProgressDashboardView body")
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
                chartsContent
                Spacer(minLength: 100)
            }
            .padding(.horizontal, AppTheme.paddingHorizontal)
        }
        .minimizeTabBarOnScroll(
            tabBarState: tabBarState
        )
        .refreshable {
            async let analytics: () = analyticsVM.refreshData()
            async let charts: () = chartVM.refreshData()
            async let goals: () = goalsVM.loadGoals()
            (_, _, _) = await (analytics, charts, goals)
        }
        .onAppear { AnalyticsManager.shared.track(.screenView(screen: "progress")) }
        .task {
            async let analytics: () = analyticsVM.loadAnalytics()
            async let charts: () = chartVM.loadChartData()
            async let goals: () = goalsVM.loadGoals()
            (_, _, _) = await (analytics, charts, goals)
            let revision = progressRefreshState.revision
            switch analyticsVM.state {
            case .loaded, .empty:
                analyticsVM.markRevisionAsCurrent(revision)
            default:
                break
            }
            if case .loaded = chartVM.chartState {
                chartVM.markRevisionAsCurrent(revision)
            }
        }
        .onChange(of: isActive) { _, active in
            guard active else { return }
            let revision = progressRefreshState.revision
            Task {
                async let analytics: () = analyticsVM.refreshIfNeeded(currentRevision: revision)
                async let charts: () = chartVM.refreshIfNeeded(currentRevision: revision)
                (_, _) = await (analytics, charts)
            }
        }
        .sheet(isPresented: $chartVM.showDaySheet) {
            DayDetailSheet(
                dateStr: chartVM.selectedDateStr,
                food: chartVM.selectedDateFood,
                water: chartVM.selectedDateWater,
                goals: chartVM.selectedDateGoals,
                state: chartVM.dayDetailState,
                activity: chartVM.selectedDateActivity
            )
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Progress")
                .font(Font.h1)
                .foregroundColor(AppTheme.textPrimary)
                .padding(.top, AppTheme.headerPaddingTop)
            Text("Your nutrition trends")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
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
            ErrorMessageView(text: error.localizedDescription)
        }
    }

    @ViewBuilder
    private var chartsContent: some View {
        switch chartVM.chartState {
        case .idle, .loading:
            ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.vertical, 20)
        case .loaded(let data):
            if !data.isEmpty {
                VStack(spacing: 20) {
                    CaloriesChartView(data: data, canTap: chartVM.canTapBars, onBarTap: { chartVM.handleBarTap(point: $0) }, initialScrollX: data.first?.label ?? "")
                    WaterChartView(data: data, canTap: chartVM.canTapBars, onBarTap: { chartVM.handleBarTap(point: $0) }, initialScrollX: data.first?.label ?? "")
                    NutritionChartView(data: data, canTap: chartVM.canTapBars, onBarTap: { chartVM.handleBarTap(point: $0) }, initialScrollX: data.first?.label ?? "")
                    ActivityChartView(data: data, canTap: chartVM.canTapBars, onBarTap: { chartVM.handleBarTap(point: $0) }, initialScrollX: data.first?.label ?? "")
                }
            } else {
                if case .empty = analyticsVM.state {
                    EmptyView()
                } else {
                    emptyState
                }
            }
        case .error:
            EmptyView()
        }
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
                .font(Font.largeNumber)
                .foregroundColor(AppTheme.textSecondary)
            Text("No data for this period")
                .font(.headline)
                .foregroundColor(AppTheme.textSecondary)
            Text("Start tracking to see statistics")
                .font(.subheadline)
                .foregroundColor(AppTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
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
            .background(AppTheme.background)
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
            activityService: MockActivityService()
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
