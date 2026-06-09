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

            content(for: selectedTab)

            CustomTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            if analyticsVM == nil {
                analyticsVM = AnalyticsViewModel(coordinator: coordinator, service: container.analyticsService, periodState: periodState)
                dailyVM = DailySummaryViewModel(coordinator: coordinator, service: container.dailySummaryService, periodState: periodState)
            }
        }
    }

    @ViewBuilder
    private func content(for tab: Int) -> some View {
        switch tab {
        case 0:
            HomeFactory.make(container: container, coordinator: coordinator)
        case 1:
            if let analyticsVM, let dailyVM {
                ProgressDashboardView(analyticsVM: analyticsVM, dailyVM: dailyVM, periodState: periodState)
            }
        default:
            SettingsFactory.make(container: container, coordinator: coordinator)
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

        return ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()

            previewContent(for: selectedTab, coordinator: coordinator, homeVM: homeVM, profileVM: profileVM)

            CustomTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func previewContent(for tab: Int, coordinator: AppCoordinator, homeVM: HomeViewModel, profileVM: ProfileViewModel) -> some View {
        switch tab {
        case 0:
            HomeView(homeViewModel: homeVM)
        case 1:
            let periodState = PeriodState()
            ProgressDashboardView(
                analyticsVM: AnalyticsViewModel(
                    coordinator: coordinator,
                    service: MockAnalyticsService(),
                    periodState: periodState
                ),
                dailyVM: DailySummaryViewModel(
                    coordinator: coordinator,
                    service: MockDailySummaryService(),
                    periodState: periodState,
                    foodService: MockFoodService(),
                    waterService: MockWaterService()
                ),
                periodState: periodState
            )
        default:
            SettingsView(viewModel: profileVM)
        }
    }
}
