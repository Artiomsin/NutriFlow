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
                dailyVM = DailySummaryViewModel(coordinator: coordinator, service: container.dailySummaryService, periodState: periodState, foodService: container.foodService, waterService: container.waterTrackingService, goalsService: container.goalsService)
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
    @State private var periodState = PeriodState()
    @State private var foodVM = FoodViewModel(service: MockFoodService())
    @State private var waterVM = WaterViewModel(service: MockWaterService())
    @State private var dailyVM = DailySummaryViewModel(
        coordinator: AppCoordinator(container: AppDependencyContainer()),
        service: MockDailySummaryService(),
        foodService: MockFoodService(),
        waterService: MockWaterService()
    )
    @State private var goalsVM: GoalsViewModel = {
        let vm = GoalsViewModel(service: MockGoalsService())
        vm.state = .loaded(UserGoals(
            id: "1", userId: "1",
            dailyCaloriesGoal: 2200, dailyProteinGoal: 150,
            dailyFatGoal: 65, dailyCarbsGoal: 250, dailyWaterGoal: 3000,
            source: "auto", createdAt: nil, updatedAt: nil
        ))
        return vm
    }()
    @State private var profileVM = ProfileViewModel(
        coordinator: AppCoordinator(container: AppDependencyContainer()),
        authService: MockAuthService(),
        profileService: MockProfileService(),
        userService: MockUserService()
    )
    @State private var analyticsVM = AnalyticsViewModel(
        coordinator: AppCoordinator(container: AppDependencyContainer()),
        service: MockAnalyticsService(),
        periodState: PeriodState()
    )
    @State private var progressDailyVM = DailySummaryViewModel(
        coordinator: AppCoordinator(container: AppDependencyContainer()),
        service: MockDailySummaryService(),
        periodState: PeriodState(),
        foodService: MockFoodService(),
        waterService: MockWaterService(),
        goalsService: MockGoalsService()
    )

    var body: some View {
        let homeVM = HomeViewModel(
            coordinator: AppCoordinator(container: AppDependencyContainer()),
            foodViewModel: foodVM,
            waterViewModel: waterVM,
            dailyViewModel: dailyVM,
            goalsViewModel: goalsVM
        )

        ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()

            Group {
                switch selectedTab {
                case 0:
                    HomeView(homeViewModel: homeVM)
                case 1:
                    ProgressDashboardView(
                        analyticsVM: analyticsVM,
                        dailyVM: progressDailyVM,
                        periodState: periodState
                    )
                case 2:
                    SettingsView(viewModel: profileVM)
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 20)
        }
        .preferredColorScheme(.dark)
    }
}
