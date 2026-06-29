import SwiftUI

struct ProgressDashboardView: View {
    @Bindable var analyticsVM: AnalyticsViewModel
    @Bindable var chartVM: ProgressChartViewModel
    @Bindable var periodState: PeriodState
    let isGuest: Bool

    var body: some View {
        let _ = print("ProgressDashboardView body")
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                header

                if isGuest {
                    GuestBanner(onRegister: { analyticsVM.goToAuth() })
                }

                PeriodSelectorView(
                    selectedPeriod: periodState.type,
                    fromDate: periodState.fromDate,
                    toDate: periodState.toDate,
                    isGuest: isGuest,
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
        .refreshable {
            async let analytics: () = analyticsVM.refreshData()
            async let charts: () = chartVM.refreshData()
            (_, _) = await (analytics, charts)
        }
        .onAppear { AnalyticsManager.shared.track(.screenView(screen: "progress")) }
        .task {
            async let analytics: () = analyticsVM.loadAnalytics()
            async let charts: () = chartVM.loadChartData()
            (_, _) = await (analytics, charts)
        }
        .sheet(isPresented: $chartVM.showDaySheet) {
            DayDetailSheet(
                dateStr: chartVM.selectedDateStr,
                food: chartVM.selectedDateFood,
                water: chartVM.selectedDateWater,
                goals: chartVM.selectedDateGoals
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
        switch chartVM.chartState {
        case .idle, .loading:
            ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.vertical, 20)
        case .loaded(let data):
            if !data.isEmpty {
                VStack(spacing: 20) {
                    CaloriesChartView(data: data, canTap: chartVM.canTapBars, onBarTap: { chartVM.handleBarTap(label: $0) })
                    WaterChartView(data: data, canTap: chartVM.canTapBars, onBarTap: { chartVM.handleBarTap(label: $0) })
                    NutritionChartView(data: data, canTap: chartVM.canTapBars, onBarTap: { chartVM.handleBarTap(label: $0) })
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
        return ProgressDashboardView(analyticsVM: data.analytics, chartVM: data.chart, periodState: data.period, isGuest: false)
            .background(AppTheme.background)
    }

    private func makePreviewData() -> (analytics: AnalyticsViewModel, chart: ProgressChartViewModel, period: PeriodState) {
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
            goalsService: MockGoalsService()
        )
        return (analyticsVM, chartVM, periodState)
    }
}
