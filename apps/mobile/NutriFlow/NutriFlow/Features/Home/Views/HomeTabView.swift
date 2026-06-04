import SwiftUI

struct HomeTabView: View {

    @Bindable var session: SessionManager
    @Bindable var homeViewModel: HomeViewModel

    @State private var showAddFood = false
    @State private var showAddWater = false

    var body: some View {

        ScrollView(showsIndicators: false) {

            VStack(spacing: 24) {

                header
                
                DailySummarySection(viewModel: homeViewModel.dailyViewModel)
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

                Spacer(minLength: 100)
            }
            .background(AppTheme.background)
        }
        .task {
            await homeViewModel.loadAll()
        }
        .fullScreenCover(isPresented: $showAddFood) {
            AddFoodView(
                foodViewModel: homeViewModel.foodViewModel,
                onSave: {
                    Task {
                        homeViewModel.dailyViewModel.invalidateCache()
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
                        homeViewModel.dailyViewModel.invalidateCache()
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

            Text("Track your food and water intake")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}

#Preview {
    HomeTabViewPreview()
}

struct HomeTabViewPreview: View {
    var body: some View {
        let session = SessionManager(tokenStorage: TokenStorage(keychain: KeychainService()))

        let foodVM = FoodViewModel(
            session: session,
            service: MockFoodService()
        )
        foodVM.setPreviewState(.loaded([
            FoodEntry(id: "1", userId: "1", name: "Chicken breast", calories: 165, protein: 31, fat: 4, carbs: 0, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil),
            FoodEntry(id: "2", userId: "1", name: "Rice", calories: 200, protein: 4, fat: 1, carbs: 45, createdAt: "2026-05-18T12:00:00Z", updatedAt: nil)
        ]))

        let waterVM = WaterViewModel(
            session: session,
            service: MockWaterService()
        )
        waterVM.setPreviewState(.loaded([
            WaterEntry(id: "1", userId: "1", amountMl: 250, createdAt: "2026-05-18T08:00:00Z", updatedAt: nil),
            WaterEntry(id: "2", userId: "1", amountMl: 500, createdAt: "2026-05-18T10:30:00Z", updatedAt: nil)
        ]))

        let dailyVM = DailySummaryViewModel(
            session: session,
            service: MockDailySummaryService()
        )
        dailyVM.setPreviewState(.loaded(DailySummary(
            id: "1",
            userId: "1",
            date: "2026-05-18",
            totalCalories: 1250,
            totalProtein: 85,
            totalFat: 42,
            totalCarbs: 120,
            totalWaterMl: 1750,
            createdAt: "2026-05-18T10:00:00Z",
            updatedAt: nil
        )))

        let homeVM = HomeViewModel(
            foodViewModel: foodVM,
            waterViewModel: waterVM,
            dailyViewModel: dailyVM
        )

        return HomeTabFlow(homeViewModel: homeVM, session: session)
            .preferredColorScheme(.dark)
    }
}
