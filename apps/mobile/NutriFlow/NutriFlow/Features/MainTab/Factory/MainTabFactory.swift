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
    @State private var periodState: PeriodState
    @State private var analyticsVM: AnalyticsViewModel
    @State private var profileVM: ProfileViewModel

    init(container: AppDependency, coordinator: AppCoordinator) {
        self.container = container
        self.coordinator = coordinator

        let period = PeriodState()
        self._periodState = State(initialValue: period)

        self._analyticsVM = State(initialValue: AnalyticsViewModel(
            coordinator: coordinator,
            service: container.analyticsService,
            periodState: period
        ))

        self._profileVM = State(initialValue: ProfileViewModel(
            coordinator: coordinator,
            authService: container.authService,
            profileService: container.profileService,
            userService: container.userService
        ))
    }

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
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            HomeFactory.make(
                coordinator: coordinator,
                foodService: container.foodService,
                waterService: container.waterTrackingService,
                goalsService: container.goalsService,
                dailySummaryService: container.dailySummaryService
            )
        case 1:
            ProgressFactory.make(
                coordinator: coordinator,
                container: container,
                periodState: periodState,
                analyticsVM: analyticsVM
            )
        case 2:
            SettingsFactory.make(profileViewModel: profileVM)
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
    @State private var foodVM = FoodViewModel(coordinator: AppCoordinator(container: AppDependencyContainer()), service: MockFoodService())
    @State private var waterVM = WaterViewModel(coordinator: AppCoordinator(container: AppDependencyContainer()), service: MockWaterService())
    @State private var goalsVM: GoalsViewModel = {
        let vm = GoalsViewModel(coordinator: AppCoordinator(container: AppDependencyContainer()), service: MockGoalsService())
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

    var body: some View {
        let homeVM = HomeViewModel(
            coordinator: AppCoordinator(container: AppDependencyContainer()),
            dailySummaryService: MockDailySummaryService(),
            foodViewModel: foodVM,
            waterViewModel: waterVM,
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
                        chartVM: ProgressChartViewModel(
                            coordinator: AppCoordinator(container: AppDependencyContainer()),
                            service: MockDailySummaryService(),
                            periodState: periodState,
                            foodService: MockFoodService(),
                            waterService: MockWaterService(),
                            goalsService: MockGoalsService()
                        ),
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
