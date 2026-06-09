import SwiftUI

struct HomeView: View {

    @Bindable var homeViewModel: HomeViewModel

    @State private var showAddFood = false
    @State private var showAddWater = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                header

                DailySummarySection(
                    viewModel: homeViewModel.dailyViewModel,
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
            AmplitudeService.shared.track(.screenView(screen: "home"))
            Task { await homeViewModel.reloadGoals() }
        }
        .fullScreenCover(isPresented: $showAddFood) {
            AddFoodView(
                foodViewModel: homeViewModel.foodViewModel,
                onSave: {
                    Task {
                        await homeViewModel.dailyViewModel.loadToday()
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showAddWater) {
            AddWaterView(
                waterViewModel: homeViewModel.waterViewModel,
                onSave: {
                    Task {
                        await homeViewModel.dailyViewModel.loadToday()
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

struct HomePreviewContent: View {
    var body: some View {
        let foodVM = FoodViewModel(
            service: MockFoodService()
        )
        foodVM.setPreviewState(.loaded([
            FoodEntry(id: "1", userId: "1", name: "Chicken breast", calories: 165, protein: 31, fat: 4, carbs: 0, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil),
            FoodEntry(id: "2", userId: "1", name: "Rice", calories: 200, protein: 4, fat: 1, carbs: 45, createdAt: "2026-05-18T12:00:00Z", updatedAt: nil)
        ]))

        let waterVM = WaterViewModel(
            service: MockWaterService()
        )
        waterVM.setPreviewState(.loaded([
            WaterEntry(id: "1", userId: "1", amountMl: 250, createdAt: "2026-05-18T08:00:00Z", updatedAt: nil),
            WaterEntry(id: "2", userId: "1", amountMl: 500, createdAt: "2026-05-18T10:30:00Z", updatedAt: nil)
        ]))

        let dailyVM = DailySummaryViewModel(
            coordinator: AppCoordinator(container: AppDependencyContainer()),
            service: MockDailySummaryService()
        )
        dailyVM.setPreviewState(.loaded(DailySummary(
            id: "1",
            userId: "1",
            date: "2026-05-20",
            totalCalories: 1250,
            totalProtein: 85,
            totalFat: 42,
            totalCarbs: 120,
            totalWaterMl: 1750,
            createdAt: "2026-05-20T10:00:00Z",
            updatedAt: nil
        )))

        let goalsVM = GoalsViewModel(service: MockGoalsService())
        goalsVM.state = .loaded(UserGoals(
            id: "1",
            userId: "1",
            dailyCaloriesGoal: 2200,
            dailyProteinGoal: 150,
            dailyFatGoal: 65,
            dailyCarbsGoal: 250,
            dailyWaterGoal: 3000,
            source: "auto",
            createdAt: nil,
            updatedAt: nil
        ))

        let homeVM = HomeViewModel(
            coordinator: AppCoordinator(container: AppDependencyContainer()),
            foodViewModel: foodVM,
            waterViewModel: waterVM,
            dailyViewModel: dailyVM,
            goalsViewModel: goalsVM
        )

        return HomeView(homeViewModel: homeVM)
            .background(AppTheme.background)
            .preferredColorScheme(.dark)
    }
}
