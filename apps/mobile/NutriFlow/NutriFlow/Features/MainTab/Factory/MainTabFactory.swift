import SwiftUI

enum MainTabFactory {
    @MainActor @ViewBuilder
    static func make(container: AppDependency, coordinator: AppCoordinator, isGuest: Bool) -> some View {
        MainTabView(container: container, coordinator: coordinator, isGuest: isGuest)
    }
}

private struct MainTabView: View {
    let container: AppDependency
    let coordinator: AppCoordinator
    let isGuest: Bool
    @State private var selectedTab = 0
    @State private var periodState: PeriodState

    init(container: AppDependency, coordinator: AppCoordinator, isGuest: Bool) {
        self.container = container
        self.coordinator = coordinator
        self.isGuest = isGuest

        let period = PeriodState()
        if isGuest { period.type = .today }
        self._periodState = State(initialValue: period)
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
                container: container,
                isGuest: isGuest
            )
        case 1:
            ProgressFactory.make(
                coordinator: coordinator,
                container: container,
                periodState: periodState,
                isGuest: isGuest
            )
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
                    HomeView(homeViewModel: homeVM, isGuest: false)
                case 1:
                    ProgressDashboardView(
                        analyticsVM: AnalyticsViewModel(
                            coordinator: AppCoordinator(container: AppDependencyContainer()),
                            service: MockAnalyticsService(),
                            periodState: PeriodState()
                        ),
                        chartVM: ProgressChartViewModel(
                            coordinator: AppCoordinator(container: AppDependencyContainer()),
                            service: MockDailySummaryService(),
                            periodState: periodState,
                            foodService: MockFoodService(),
                            waterService: MockWaterService(),
                            goalsService: MockGoalsService()
                        ),
                        periodState: periodState,
                        isGuest: false
                    )
                case 2:
                    SettingsView(
                        viewModel: ProfileViewModel(
                            coordinator: AppCoordinator(container: AppDependencyContainer()),
                            authService: MockAuthService(),
                            profileService: MockProfileService(),
                            userService: MockUserService()
                        ),
                        coordinator: nil
                    )
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
