import SwiftUI

struct MainTabView: View {
    let container: AppDependency
    let coordinator: AppCoordinator

    @State private var selectedTab = 0
    @State private var periodState: PeriodState
    @State private var tabBarState = TabBarState()
    @State private var progressRefreshState: ProgressRefreshState

    @State private var homeVM: HomeViewModel
    @State private var analyticsVM: AnalyticsViewModel
    @State private var chartVM: ProgressChartViewModel
    @State private var profileVM: ProfileViewModel

    init(container: AppDependency, coordinator: AppCoordinator) {
        self.container = container
        self.coordinator = coordinator

        let period = PeriodState()
        let refreshState = ProgressRefreshState()
        self._periodState = State(initialValue: period)
        self._progressRefreshState = State(initialValue: refreshState)

        self._homeVM = State(initialValue: HomeFactory.make(
            coordinator: coordinator,
            container: container,
            progressRefreshState: refreshState
        ))

        let progress = ProgressFactory.make(
            coordinator: coordinator,
            container: container,
            periodState: period
        )
        self._analyticsVM = State(initialValue: progress.0)
        self._chartVM = State(initialValue: progress.1)

        self._profileVM = State(initialValue: ProfileViewModel(
            coordinator: coordinator,
            authService: container.authService,
            profileService: container.profileService,
            userService: container.userService,
            cacheService: container.cacheService,
            activitySync: container.activitySync
        ))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()

            HomeView(homeViewModel: homeVM, foodService: container.foodService, coordinator: coordinator, tabBarState: tabBarState)
                .equatable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(selectedTab == 0 ? 1 : 0)
                .allowsHitTesting(selectedTab == 0)

            ProgressDashboardView(
                analyticsVM: analyticsVM,
                chartVM: chartVM,
                periodState: periodState,
                tabBarState: tabBarState,
                progressRefreshState: progressRefreshState,
                isActive: selectedTab == 1
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(selectedTab == 1 ? 1 : 0)
            .allowsHitTesting(selectedTab == 1)

            SettingsView(viewModel: profileVM, coordinator: coordinator, tabBarState: tabBarState)
                .equatable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(selectedTab == 2 ? 1 : 0)
                .allowsHitTesting(selectedTab == 2)

            AnimatedTabBar(tabBarState: tabBarState, selectedTab: $selectedTab)
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea(.keyboard)
        .onChange(of: selectedTab) { _, _ in
            tabBarState.isTabBarHidden = false
            tabBarState.isTabBarMinimized = false
        }
    }
}

private struct AnimatedTabBar: View {
    let tabBarState: TabBarState
    @Binding var selectedTab: Int

    var body: some View {
        CustomTabBar(selectedTab: $selectedTab)
            .padding(.horizontal, 20)
            .scaleEffect(tabBarState.isTabBarMinimized ? 0.85 : 1, anchor: .bottom)
            .opacity(tabBarState.isTabBarHidden ? 0 : (tabBarState.isTabBarMinimized ? 0.9 : 1))
            .offset(y: tabBarState.isTabBarHidden ? 120 : (tabBarState.isTabBarMinimized ? 8 : 0))
            .animation(.easeInOut(duration: 0.35), value: tabBarState.isTabBarHidden)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: tabBarState.isTabBarMinimized)
    }
}

#Preview("All Screens") {
    let container = AppDependencyContainer()
    let coordinator = AppCoordinator(container: container)
    MainTabView(container: container, coordinator: coordinator)
}
