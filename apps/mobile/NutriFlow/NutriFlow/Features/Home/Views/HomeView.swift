import SwiftUI

struct HomeView: View {

    @Bindable var homeViewModel: HomeViewModel
    let isGuest: Bool

    @State private var showAddFood = false
    @State private var showAddWater = false

    var body: some View {
        let _ = print("HomeView body")
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                header

                if isGuest {
                    GuestBanner(onRegister: { homeViewModel.goToAuth() })
                }

                DailySummarySectionView(homeViewModel: homeViewModel)
                FoodSectionView(
                    foodViewModel: homeViewModel.foodViewModel,
                    onAddFood: { showAddFood = true },
                    onDeleteFood: { id in
                        Task { await homeViewModel.deleteFood(id: id) }
                    }
                )
                WaterSectionView(
                    waterViewModel: homeViewModel.waterViewModel,
                    onAddWater: { showAddWater = true },
                    onDeleteWater: { id in
                        Task { await homeViewModel.deleteWater(id: id) }
                    }
                )
            }
            .padding(.bottom, 100)
        }
        .refreshable { await homeViewModel.refreshAll() }
        .task { await homeViewModel.loadAll() }
        .onAppear {
            AnalyticsManager.shared.track(.screenView(screen: "home"))
            Task { await homeViewModel.reloadGoals() }
            homeViewModel.checkExpiredDay()
        }
        .fullScreenCover(isPresented: $showAddFood) {
            AddFoodView(
                foodViewModel: homeViewModel.foodViewModel,
                onSave: { Task { await homeViewModel.loadToday() } }
            )
        }
        .fullScreenCover(isPresented: $showAddWater) {
            AddWaterView(
                waterViewModel: homeViewModel.waterViewModel,
                onSave: { Task { await homeViewModel.loadToday() } }
            )
        }
        .sheet(isPresented: $homeViewModel.showExpiredWarning, onDismiss: {
            Task { await homeViewModel.handleSheetDismiss() }
            Task { await homeViewModel.loadAll() }
        }) {
            ExpiredDaySheet(
                onRegister: { homeViewModel.goToAuthFromSheet() },
                onDismiss: { Task { await homeViewModel.dismissExpiredDay() } }
            )
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Home")
                .font(Font.h1)
                .foregroundColor(AppTheme.textPrimary)
                .padding(.top, AppTheme.headerPaddingTop)
        }
    }
}

private struct DailySummarySectionView: View {
    @Bindable var homeViewModel: HomeViewModel

    var body: some View {
        DailySummarySection(
            state: homeViewModel.dailySummaryState,
            goals: homeViewModel.userGoals
        )
        .padding(.horizontal, AppTheme.paddingHorizontal)
    }
}

private struct FoodSectionView: View {
    @Bindable var foodViewModel: FoodViewModel
    let onAddFood: () -> Void
    let onDeleteFood: (String) -> Void

    var body: some View {
        FoodSection(
            foodViewModel: foodViewModel,
            onAddFood: onAddFood,
            onDeleteFood: onDeleteFood
        )
        .padding(.horizontal, AppTheme.paddingHorizontal)
    }
}

private struct WaterSectionView: View {
    @Bindable var waterViewModel: WaterViewModel
    let onAddWater: () -> Void
    let onDeleteWater: (String) -> Void

    var body: some View {
        WaterSection(
            waterViewModel: waterViewModel,
            onAddWater: onAddWater,
            onDeleteWater: onDeleteWater
        )
        .padding(.horizontal, AppTheme.paddingHorizontal)
    }
}

struct GuestBanner: View {
    let onRegister: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.badge.plus")
                .foregroundColor(AppTheme.accent)
            Text("Guest mode — register to save your data")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Register", action: onRegister)
                .font(.footnote.weight(.semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.accent)
                .cornerRadius(16)
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
}

struct ExpiredDaySheet: View {
    let onRegister: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.accent)

            Text("New day started")
                .font(Font.h2)
                .foregroundColor(AppTheme.textPrimary)

            Text("Your guest data from yesterday will be lost. Register to keep tracking your progress.")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button("Register", action: onRegister)
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.accent)
                .cornerRadius(12)

            Button("Continue as Guest", action: onDismiss)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(24)
        .background(AppTheme.background)
        .presentationDetents([.height(320)])
    }
}

#Preview {
    HomePreviewContent()
}

private struct HomePreviewContent: View {
    var body: some View {
        return HomeView(homeViewModel: makePreviewHomeVM(), isGuest: false)
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
