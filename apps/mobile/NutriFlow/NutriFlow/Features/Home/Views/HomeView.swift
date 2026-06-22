import SwiftUI

struct HomeView: View {

    @Bindable var homeViewModel: HomeViewModel

    @State private var showAddFood = false
    @State private var showAddWater = false

    var body: some View {
        let _ = print("HomeView body")
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                header

                DailySummarySection(
                    state: homeViewModel.dailySummaryState,
                    goals: homeViewModel.userGoals
                )
                .padding(.horizontal, AppTheme.paddingHorizontal)

                FoodSection(
                    foodViewModel: homeViewModel.foodViewModel,
                    onAddFood: { showAddFood = true },
                    onDeleteFood: { id in
                        Task {
                            await homeViewModel.deleteFood(id: id)
                        }
                    }
                )
                .padding(.horizontal, AppTheme.paddingHorizontal)

                WaterSection(
                    waterViewModel: homeViewModel.waterViewModel,
                    onAddWater: { showAddWater = true },
                    onDeleteWater: { id in
                        Task {
                            await homeViewModel.deleteWater(id: id)
                        }
                    }
                )
                .padding(.horizontal, AppTheme.paddingHorizontal)

            }
            .padding(.bottom, 100)
        }
        .task {
            await homeViewModel.loadAll()
        }
        .onAppear {
            AnalyticsManager.shared.track(.screenView(screen: "home"))
            Task { await homeViewModel.reloadGoals() }
        }
        .fullScreenCover(isPresented: $showAddFood) {
            AddFoodView(
                foodViewModel: homeViewModel.foodViewModel,
                onSave: {
                    Task {
                        await homeViewModel.loadToday()
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showAddWater) {
            AddWaterView(
                waterViewModel: homeViewModel.waterViewModel,
                onSave: {
                    Task {
                        await homeViewModel.loadToday()
                    }
                }
            )
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Home")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.top, AppTheme.headerPaddingTop)
        }
    }
}

#Preview {
    HomePreviewContent()
}

private struct HomePreviewContent: View {
    var body: some View {
        return HomeView(homeViewModel: makePreviewHomeVM())
            .background(AppTheme.background)
            .preferredColorScheme(.dark)
    }

    private func makePreviewHomeVM() -> HomeViewModel {
        let coordinator = AppCoordinator(container: AppDependencyContainer())
        let foodVM = FoodViewModel(coordinator: coordinator, service: MockFoodService())
        foodVM.setPreviewState(.loaded([
            FoodEntry(id: "1", userId: "1", name: "Chicken breast", calories: 165, protein: 31, fat: 4, carbs: 0, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil),
            FoodEntry(id: "2", userId: "1", name: "Rice", calories: 200, protein: 4, fat: 1, carbs: 45, createdAt: "2026-05-18T12:00:00Z", updatedAt: nil)
        ]))

        let waterVM = WaterViewModel(coordinator: coordinator, service: MockWaterService())
        waterVM.setPreviewState(.loaded([
            WaterEntry(id: "1", userId: "1", amountMl: 250, createdAt: "2026-05-18T08:00:00Z", updatedAt: nil),
            WaterEntry(id: "2", userId: "1", amountMl: 500, createdAt: "2026-05-18T10:30:00Z", updatedAt: nil)
        ]))

        let goalsVM = GoalsViewModel(coordinator: coordinator, service: MockGoalsService())
        goalsVM.state = .loaded(UserGoals(
            id: "1", userId: "1",
            dailyCaloriesGoal: 2200, dailyProteinGoal: 150,
            dailyFatGoal: 65, dailyCarbsGoal: 250, dailyWaterGoal: 3000,
            source: "auto", createdAt: nil, updatedAt: nil
        ))

        return HomeViewModel(
            coordinator: coordinator,
            dailySummaryService: MockDailySummaryService(),
            foodViewModel: foodVM,
            waterViewModel: waterVM,
            goalsViewModel: goalsVM
        )
    }
}
