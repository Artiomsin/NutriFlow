import SwiftUI

struct MainTabView: View {
    let container: AppDependency
    let coordinator: AppCoordinator
    let isGuest: Bool

    @State private var selectedTab = 0
    @State private var periodState: PeriodState

    @State private var homeVM: HomeViewModel
    @State private var analyticsVM: AnalyticsViewModel
    @State private var chartVM: ProgressChartViewModel
    @State private var profileVM: ProfileViewModel

    init(container: AppDependency, coordinator: AppCoordinator, isGuest: Bool) {
        self.container = container
        self.coordinator = coordinator
        self.isGuest = isGuest

        let period = PeriodState()
        if isGuest { period.type = .today }
        self._periodState = State(initialValue: period)

        self._homeVM = State(initialValue: HomeFactory.make(
            coordinator: coordinator,
            container: container,
            isGuest: isGuest
        ))

        let progress = ProgressFactory.make(
            coordinator: coordinator,
            container: container,
            periodState: period,
            isGuest: isGuest
        )
        self._analyticsVM = State(initialValue: progress.0)
        self._chartVM = State(initialValue: progress.1)

        self._profileVM = State(initialValue: ProfileViewModel(
            coordinator: coordinator,
            authService: container.authService,
            profileService: container.profileService,
            userService: container.userService,
            cacheService: container.cacheService
        ))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()

            HomeView(homeViewModel: homeVM, isGuest: isGuest)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(selectedTab == 0 ? 1 : 0)
                .allowsHitTesting(selectedTab == 0)

            ProgressDashboardView(
                analyticsVM: analyticsVM,
                chartVM: chartVM,
                periodState: periodState,
                isGuest: isGuest
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(selectedTab == 1 ? 1 : 0)
            .allowsHitTesting(selectedTab == 1)

            SettingsView(viewModel: profileVM, coordinator: coordinator)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(selectedTab == 2 ? 1 : 0)
                .allowsHitTesting(selectedTab == 2)

            CustomTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 20)
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea(.keyboard)
    }
}

#Preview("All Screens") {
    let container = AppDependencyContainer()
    let coordinator = AppCoordinator(container: container)
    MainTabView(container: container, coordinator: coordinator, isGuest: false)
}
