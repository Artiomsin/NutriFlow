import SwiftUI

struct ProgressDashboardView: View {
    @Bindable var analyticsVM: AnalyticsViewModel
    @Bindable var dailyVM: DailySummaryViewModel
    @Bindable var periodState: PeriodState

    @State private var searchDate = Date()
    @State private var showSearch = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                header
                dateSearchSection
                PeriodSelectorView(
                    selectedPeriod: periodState.type,
                    fromDate: periodState.fromDate,
                    toDate: periodState.toDate,
                    onPeriodChange: {
                        analyticsVM.setPeriod($0)
                        dailyVM.setPeriod($0)
                    },
                    onCustomRange: { from, to in
                        analyticsVM.setCustomRange(from: from, to: to)
                        dailyVM.setCustomRange(from: from, to: to)
                    }
                )
                analyticsContent
                chartsContent
                Spacer(minLength: 100)
            }
            .padding(.horizontal, AppTheme.paddingHorizontal)
        }
        .onAppear { AmplitudeService.shared.track(.screenView(screen: "progress")) }
        .task {
            async let analytics: () = analyticsVM.loadAnalytics()
            async let charts: () = dailyVM.loadChartData()
            (_, _) = await (analytics, charts)
        }
        .sheet(isPresented: $dailyVM.showDaySheet) {
            DayDetailSheet(
                dateStr: dailyVM.selectedDateStr,
                food: dailyVM.selectedDateFood,
                water: dailyVM.selectedDateWater,
                goals: dailyVM.selectedDateGoals
            )
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Progress")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.top, AppTheme.headerPaddingTop)
            Text("Your nutrition trends")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
        }
    }

    private var dateSearchSection: some View {
        VStack(spacing: 16) {
            Button {
                withAnimation { showSearch.toggle() }
                if showSearch {
                    Task { await dailyVM.loadSearch(date: searchDate) }
                }
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.accent)
                    Text("Search by date")
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: showSearch ? "chevron.up" : "chevron.down")
                        .foregroundColor(AppTheme.textTertiary)
                        .font(.caption)
                }
                .padding(12)
                .background(AppTheme.cardBackground)
                .cornerRadius(AppTheme.cornerRadiusSmall)
            }

            if showSearch {
                DatePicker("Select date", selection: $searchDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .preferredColorScheme(.dark)
                    .onChange(of: searchDate) { _, newDate in
                        Task { await dailyVM.loadSearch(date: newDate) }
                    }

                if dailyVM.searchIsLoading {
                    ProgressView().tint(.white).padding(.vertical, 20)
                } else if !dailyVM.searchFood.isEmpty || !dailyVM.searchWater.isEmpty || dailyVM.searchGoals != nil {
                    searchResultContent
                } else {
                    Text("No entries for this date")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textTertiary)
                        .padding(.vertical, 20)
                }
            }
        }
    }

    private var searchResultContent: some View {
        VStack(spacing: 16) {
            let totalCal = dailyVM.searchFood.reduce(0) { $0 + $1.calories }
            let totalWater = dailyVM.searchWater.reduce(0) { $0 + $1.amountMl }

            HStack(spacing: 24) {
                DetailStatCard(icon: "flame.fill", color: .orange, value: "\(totalCal)", unit: "kcal")
                DetailStatCard(icon: "drop.fill", color: .cyan, value: "\(totalWater)", unit: "ml")
                DetailStatCard(icon: "fork.knife", color: .green, value: "\(dailyVM.searchFood.count)", unit: "meals")
            }

            if let goals = dailyVM.searchGoals {
                goalsSection(goals, calories: totalCal, water: totalWater)
            }

            foodList
            waterList
        }
    }

    private func goalsSection(_ goals: UserGoals, calories: Int, water: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Daily Goals", icon: "target")
            GoalBar(title: "Calories", current: calories, goal: goals.dailyCaloriesGoal ?? 0, unit: "kcal", color: .orange, icon: "flame.fill")
            GoalBar(title: "Protein", current: dailyVM.searchFood.reduce(0) { $0 + ($1.protein ?? 0) }, goal: goals.dailyProteinGoal ?? 0, unit: "g", color: .indigo, icon: "bolt.fill")
            GoalBar(title: "Fat", current: dailyVM.searchFood.reduce(0) { $0 + ($1.fat ?? 0) }, goal: goals.dailyFatGoal ?? 0, unit: "g", color: .green, icon: "drop.degreesign.fill")
            GoalBar(title: "Carbs", current: dailyVM.searchFood.reduce(0) { $0 + ($1.carbs ?? 0) }, goal: goals.dailyCarbsGoal ?? 0, unit: "g", color: .purple, icon: "leaf.arrow.circlepath")
            GoalBar(title: "Water", current: water, goal: goals.dailyWaterGoal ?? 0, unit: "ml", color: .cyan, icon: "drop.fill")
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }

    private var foodList: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Food", icon: "fork.knife")
            if dailyVM.searchFood.isEmpty {
                emptyRow("No food entries")
            } else {
                ForEach(dailyVM.searchFood) { entry in
                    FoodRow(entry: entry)
                    if entry.id != dailyVM.searchFood.last?.id {
                        Divider().background(AppTheme.textTertiary.opacity(0.15))
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }

    private var waterList: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Water", icon: "drop.fill")
            if dailyVM.searchWater.isEmpty {
                emptyRow("No water entries")
            } else {
                ForEach(dailyVM.searchWater) { entry in
                    WaterRow(entry: entry)
                    if entry.id != dailyVM.searchWater.last?.id {
                        Divider().background(AppTheme.textTertiary.opacity(0.15))
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }

    private func sectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(AppTheme.accent)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.textPrimary)
        }
    }

    private func emptyRow(_ text: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "tray")
                    .font(.title3)
                    .foregroundColor(AppTheme.textTertiary)
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textTertiary)
            }
            .padding(.vertical, 20)
            Spacer()
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

                ringGrid(analytics: analytics)

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
        switch dailyVM.chartState {
        case .idle, .loading:
            ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.vertical, 20)
        case .loaded(let data):
            if !data.isEmpty {
                VStack(spacing: 20) {
                    CaloriesChartView(data: data, canTap: dailyVM.canTapBars, onBarTap: { dailyVM.handleBarTap(label: $0) })
                    WaterChartView(data: data, canTap: dailyVM.canTapBars, onBarTap: { dailyVM.handleBarTap(label: $0) })
                    NutritionChartView(data: data, canTap: dailyVM.canTapBars, onBarTap: { dailyVM.handleBarTap(label: $0) })
                }
            } else {
                emptyState
            }
        case .error:
            EmptyView()
        }
    }

    private func ringGrid(analytics: AnalyticsResponse) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
            spacing: 12
        ) {
            RingProgressView(
                pct: analytics.goalCaloriesPct ?? 0,
                color: .orange,
                icon: "flame.fill",
                title: "Calories",
                value: "\(analytics.averageCalories)",
                unit: "kcal"
            )
            RingProgressView(
                pct: analytics.goalProteinPct ?? 0,
                color: .indigo,
                icon: "bolt.fill",
                title: "Protein",
                value: "\(analytics.averageProtein)",
                unit: "g"
            )
            RingProgressView(
                pct: analytics.goalFatPct ?? 0,
                color: .green,
                icon: "drop.degreesign.fill",
                title: "Fat",
                value: "\(analytics.averageFat)",
                unit: "g"
            )
            RingProgressView(
                pct: analytics.goalCarbsPct ?? 0,
                color: .purple,
                icon: "leaf.arrow.circlepath",
                title: "Carbs",
                value: "\(analytics.averageCarbs)",
                unit: "g"
            )
            RingProgressView(
                pct: analytics.goalWaterPct ?? 0,
                color: .cyan,
                icon: "drop.fill",
                title: "Water",
                value: "\(analytics.averageWater)",
                unit: "ml"
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 50))
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
    let container = AppDependencyContainer()
    let coordinator = AppCoordinator(container: container)
    let periodState = PeriodState()
    periodState.type = .week
    let analyticsVM = AnalyticsViewModel(
        coordinator: coordinator,
        service: MockAnalyticsService(),
        periodState: periodState
    )
    let dailyVM = DailySummaryViewModel(
        coordinator: coordinator,
        service: MockDailySummaryService(),
        periodState: periodState,
        foodService: MockFoodService(),
        waterService: MockWaterService(),
        goalsService: MockGoalsService()
    )
    return ProgressDashboardView(analyticsVM: analyticsVM, dailyVM: dailyVM, periodState: periodState)
        .background(AppTheme.background)
}
