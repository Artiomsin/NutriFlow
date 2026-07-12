import SwiftUI

enum HomeNavRoute: Hashable {
    case addFood
    case foodSearch
    case servingPicker(CatalogFood, Int?, String?)
}

struct HomeView: View {

    @Bindable var homeViewModel: HomeViewModel
    let isGuest: Bool
    let foodService: FoodServiceProtocol
    @Binding var isTabBarHidden: Bool

    @State private var navPath: [HomeNavRoute] = []
    @State private var showAddWater = false

    init(homeViewModel: HomeViewModel, isGuest: Bool, foodService: FoodServiceProtocol, isTabBarHidden: Binding<Bool> = .constant(false)) {
        self.homeViewModel = homeViewModel
        self.isGuest = isGuest
        self.foodService = foodService
        self._isTabBarHidden = isTabBarHidden
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            content
                .navigationDestination(for: HomeNavRoute.self) { route in
                    switch route {
                    case .addFood:
                        AddFoodView(onSave: popToRoot, foodService: foodService, todayFoodVM: homeViewModel.todayFoodVM, onSearchCatalog: {
                            navPath.append(HomeNavRoute.foodSearch)
                        })
                    case .foodSearch:
                        FoodSearchView(
                            foodService: foodService,
                            onSelect: { food, suggestedGrams, suggestedUnit in
                                navPath.append(HomeNavRoute.servingPicker(food, suggestedGrams, suggestedUnit))
                            }
                        )
                    case .servingPicker(let food, let suggestedGrams, let suggestedUnit):
                        ServingPickerView(food: food, foodService: foodService, todayFoodVM: homeViewModel.todayFoodVM, suggestedGrams: suggestedGrams, suggestedUnit: suggestedUnit, onSave: popToRoot)
                    }
                }
        }
        .tint(AppTheme.accent)
        .onChange(of: navPath) { _, newPath in
            isTabBarHidden = !newPath.isEmpty
        }
        .fullScreenCover(isPresented: $showAddWater) {
            AddWaterView(
                waterViewModel: homeViewModel.waterVM,
                onSave: { Task { await homeViewModel.loadDashboardSummary() } }
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

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                header

                if isGuest {
                    GuestBanner(onRegister: { homeViewModel.goToAuth() })
                }

                DailySummarySectionView(homeViewModel: homeViewModel)
                FoodSectionView(
                    todayFoodVM: homeViewModel.todayFoodVM,
                    onAddFood: {
                        isTabBarHidden = true
                        navPath.append(HomeNavRoute.addFood)
                    },
                    onDeleteFood: { id in
                        Task { await homeViewModel.deleteFood(id: id) }
                    }
                )
                WaterSectionView(
                    waterVM: homeViewModel.waterVM,
                    onAddWater: { showAddWater = true },
                    onDeleteWater: { id in
                        Task { await homeViewModel.deleteWater(id: id) }
                    }
                )
            }
            .padding(.bottom, 100)
        }
        .refreshable { await homeViewModel.refreshAll() }
        .task {
            await withDiscardingTaskGroup { group in
                group.addTask { await homeViewModel.loadAll() }
                group.addTask { await homeViewModel.todayFoodVM.loadToday() }
                group.addTask { await homeViewModel.waterVM.loadToday() }
            }
        }
        .onAppear {
            AnalyticsManager.shared.track(.screenView(screen: "home"))
            Task { await homeViewModel.reloadGoals() }
            homeViewModel.checkExpiredDay()
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

    private func popToRoot() {
        navPath.removeAll()
        isTabBarHidden = false
        Task { await homeViewModel.loadDashboardSummary() }
    }
}

private struct FoodSectionView: View {
    @Bindable var todayFoodVM: TodayFoodViewModel
    let onAddFood: () -> Void
    let onDeleteFood: (String) -> Void

    var body: some View {
        FoodSection(
            todayFoodVM: todayFoodVM,
            onAddFood: onAddFood,
            onDeleteFood: onDeleteFood
        )
        .padding(.horizontal, AppTheme.paddingHorizontal)
    }
}

private struct WaterSectionView: View {
    @Bindable var waterVM: WaterViewModel
    let onAddWater: () -> Void
    let onDeleteWater: (String) -> Void

    var body: some View {
        WaterSection(
            waterViewModel: waterVM,
            onAddWater: onAddWater,
            onDeleteWater: onDeleteWater
        )
        .padding(.horizontal, AppTheme.paddingHorizontal)
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
        return HomeView(
            homeViewModel: makePreviewHomeVM(),
            isGuest: false,
            foodService: MockFoodService()
        )
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
    }

    private func makePreviewHomeVM() -> HomeViewModel {
        let coordinator = AppCoordinator(container: AppDependencyContainer())
        let todayFoodVM = TodayFoodViewModel(service: MockFoodService(), coordinator: coordinator)
        todayFoodVM.setPreviewState(.loaded([
            FoodEntry(id: "1", userId: "1", name: "Chicken breast", calories: 165, protein: 31, fat: 4, carbs: 0, foodId: nil, grams: nil, unit: "g", categoryName: nil, imageUrl: nil, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil),
            FoodEntry(id: "2", userId: "1", name: "Rice", calories: 200, protein: 4, fat: 1, carbs: 45, foodId: nil, grams: nil, unit: "g", categoryName: nil, imageUrl: nil, createdAt: "2026-05-18T12:00:00Z", updatedAt: nil)
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
            foodService: MockFoodService(),
            todayFoodVM: todayFoodVM,
            waterVM: waterVM,
            goalsVM: goalsVM
        )
    }
}
