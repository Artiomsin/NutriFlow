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

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()

            Group {
                switch selectedTab {
                case 0:
                    HomeFactory.make(container: container, coordinator: coordinator)
                case 1:
                    ProgressDashboardView(
                        viewModel: DailySummaryViewModel(
                            coordinator: coordinator,
                            service: container.dailySummaryService
                        )
                    )
                case 2:
                    SettingsFactory.make(container: container, coordinator: coordinator)
                default:
                    Color.clear
                }
            }

            CustomTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .ignoresSafeArea(.container, edges: .bottom)
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

            Group {
                switch selectedTab {
                case 0:
                    HomeView(homeViewModel: homeVM)
                case 1:
                    ProgressDashboardView(
                        viewModel: DailySummaryViewModel(
                            coordinator: coordinator,
                            service: MockDailySummaryService(),
                            foodService: MockFoodService(),
                            waterService: MockWaterService()
                        )
                    )
                case 2:
                    SettingsView(viewModel: profileVM)
                default:
                    Color.clear
                }
            }

            CustomTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .preferredColorScheme(.dark)
    }
}
