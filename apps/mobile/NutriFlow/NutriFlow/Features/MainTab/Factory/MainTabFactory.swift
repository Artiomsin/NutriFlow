import SwiftUI

enum MainTabFactory {
    @MainActor @ViewBuilder
    static func make(container: AppDependency, coordinator: AppCoordinator) -> some View {
        MainTabView(container: container, coordinator: coordinator)
    }
}

private struct MainTabView: View {
    let container: AppDependency
    let coordinator: AppCoordinator
    @State private var selectedTab = 0
    @State private var periodState = PeriodState()
    @State private var analyticsVM: AnalyticsViewModel?
    @State private var dailyVM: DailySummaryViewModel?

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()

            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 20)
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea(.keyboard)
        .onAppear {
            if analyticsVM == nil {
                analyticsVM = AnalyticsViewModel(coordinator: coordinator, service: container.analyticsService, periodState: periodState)
                dailyVM = DailySummaryViewModel(coordinator: coordinator, service: container.dailySummaryService, periodState: periodState, foodService: container.foodService, waterService: container.waterTrackingService)
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            HomeFactory.make(container: container, coordinator: coordinator)
        case 1:
            if let analyticsVM, let dailyVM {
                ProgressDashboardView(analyticsVM: analyticsVM, dailyVM: dailyVM, periodState: periodState)
            }
        case 2:
            SettingsFactory.make(container: container, coordinator: coordinator)
        default:
            EmptyView()
        }
    }
}

#Preview("All Screens") {
    PreviewMainTabView()
}

private struct PreviewMainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        let coordinator = AppCoordinator(container: AppDependencyContainer())

        let foodVM = FoodViewModel(service: MockFoodService())
        let waterVM = WaterViewModel(service: MockWaterService())
        let dailyVM = DailySummaryViewModel(
            coordinator: coordinator,
            service: MockDailySummaryService(),
            foodService: MockFoodService(),
            waterService: MockWaterService()
        )
        let goalsVM = GoalsViewModel(service: MockGoalsService())
        goalsVM.state = .loaded(UserGoals(
            id: "1", userId: "1",
            dailyCaloriesGoal: 2200, dailyProteinGoal: 150,
            dailyFatGoal: 65, dailyCarbsGoal: 250, dailyWaterGoal: 3000,
            source: "auto", createdAt: nil, updatedAt: nil
        ))

        let homeVM = HomeViewModel(
            coordinator: coordinator,
            foodViewModel: foodVM,
            waterViewModel: waterVM,
            dailyViewModel: dailyVM,
            goalsViewModel: goalsVM
        )

        let profileVM = ProfileViewModel(
            coordinator: coordinator,
            authService: MockAuthService(),
            profileService: MockProfileService(),
            userService: MockUserService()
        )

        return ZStack {
            AppTheme.background.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                HomeView(homeViewModel: homeVM)
                    .tabItem { Label("Home", systemImage: "house") }
                    .tag(0)

                ProgressDashboardView(
                    analyticsVM: AnalyticsViewModel(
                        coordinator: coordinator,
                        service: MockAnalyticsService(),
                        periodState: PeriodState()
                    ),
                    dailyVM: DailySummaryViewModel(
                        coordinator: coordinator,
                        service: MockDailySummaryService()
                    ),
                    periodState: PeriodState()
                )
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
                .tag(1)

                SettingsView(viewModel: profileVM)
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(2)
            }
        }
        .preferredColorScheme(.dark)
    }


}
