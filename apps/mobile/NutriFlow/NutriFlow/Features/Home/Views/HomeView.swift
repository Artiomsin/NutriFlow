import SwiftUI

enum HomeNavRoute: Hashable {
    case addFood
    case foodSearch
    case servingPicker(CatalogFood, Int?, String?)
    case addWater
    case scanFood
    case scanResult([FoodAnalysisItem], Data?)
}

struct HomeView: View {
    
    @Bindable var homeViewModel: HomeViewModel
    let foodService: FoodServiceProtocol
    let coordinator: AppCoordinator?
    let tabBarState: TabBarState
    
    @State private var navPath: [HomeNavRoute] = []
    @State private var editingFood: FoodEntry?
    @State private var foodSearchVM: FoodSearchViewModel?
    
    init(homeViewModel: HomeViewModel, foodService: FoodServiceProtocol, coordinator: AppCoordinator? = nil, tabBarState: TabBarState = TabBarState()) {
        self.homeViewModel = homeViewModel
        self.foodService = foodService
        self.coordinator = coordinator
        self.tabBarState = tabBarState
    }
    
    var body: some View {
        NavigationStack(path: $navPath) {
            content
                .navigationDestination(for: HomeNavRoute.self) { route in
                    switch route {
                    case .addFood:
                        let addFoodVM = AddFoodViewModel(service: foodService, coordinator: coordinator)
                        AddFoodView(onSave: popToRoot, viewModel: addFoodVM, todayFoodVM: homeViewModel.todayFoodVM, onSearchCatalog: {
                            navPath.append(HomeNavRoute.foodSearch)
                        }, onSelectPopular: { food in
                            navPath.append(HomeNavRoute.servingPicker(food, nil, nil))
                        })
                    case .foodSearch:
                        searchView
                            .task {
                                if foodSearchVM == nil {
                                    foodSearchVM = FoodSearchViewModel(service: foodService)
                                }
                            }
                        
                    case .servingPicker(let food, let suggestedGrams, let suggestedUnit):
                        let pickerVM = ServingPickerViewModel(food: food, service: foodService, todayFoodVM: homeViewModel.todayFoodVM, suggestedGrams: suggestedGrams, suggestedUnit: suggestedUnit, coordinator: coordinator)
                        ServingPickerView(viewModel: pickerVM, onSave: popToRoot)
                    case .addWater:
                        AddWaterView(
                            waterViewModel: homeViewModel.waterVM,
                            onSave: { Task { await homeViewModel.loadDashboardSummary() } }
                        )
                    case .scanFood:
                        ScanFoodView(service: foodService) { items, imageData in
                            navPath.append(HomeNavRoute.scanResult(items, imageData))
                        }
                        
                    case .scanResult(let items, let imageData):
                        let resultVM = ScanResultViewModel(
                            items: items,
                            imageData: imageData,
                            service: foodService,
                            todayFoodVM: homeViewModel.todayFoodVM,
                            coordinator: coordinator
                        )
                        ScanResultView(viewModel: resultVM, onFinished: popToRoot)
                        
                    }
                }
        }
        .tint(AppTheme.accent)
        .onChange(of: navPath) { _, newPath in
            tabBarState.isTabBarHidden = !newPath.isEmpty
        }
        .background(AppTheme.background)
        .sheet(item: $editingFood) { entry in
            let vm = EditFoodViewModel(entry: entry, foodService: foodService, coordinator: coordinator)
            EditFoodView(viewModel: vm) {
                await homeViewModel.todayFoodVM.reloadAfterAdd()
                await homeViewModel.loadDashboardSummary()
            }
        }
    }
    
    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                header
                
                DailySummarySectionView(homeViewModel: homeViewModel)
                FoodSectionView(
                    todayFoodVM: homeViewModel.todayFoodVM,
                    onAddFood: {
                        tabBarState.isTabBarHidden = true
                        navPath.append(HomeNavRoute.addFood)
                    },
                    onScan: {
                        tabBarState.isTabBarHidden = true
                        navPath.append(HomeNavRoute.scanFood)
                    },
                    onEditFood: { entry in
                        editingFood = entry
                    },
                    onDeleteFood: { id in
                        Task { await homeViewModel.deleteFood(id: id) }
                    }
                )
                WaterSectionView(
                    waterVM: homeViewModel.waterVM,
                    onAddWater: {
                        tabBarState.isTabBarHidden = true
                        navPath.append(HomeNavRoute.addWater)
                    },
                    onDeleteWater: { id in
                        Task { await homeViewModel.deleteWater(id: id) }
                    }
                )
            }
            .padding(.bottom, 100)
        }
        .background(AppTheme.background)
        .minimizeTabBarOnScroll(
            tabBarState: tabBarState,
            isActive: { navPath.isEmpty }
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
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
        }
    }
    
    @ViewBuilder
    private var searchView: some View {
        if let vm = foodSearchVM {
            FoodSearchView(viewModel: vm) { food, sg, su in
                navPath.append(.servingPicker(food, sg, su))
            }
        } else {
            ProgressView()
                .tint(AppTheme.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        tabBarState.isTabBarHidden = false
        tabBarState.isTabBarMinimized = false
        Task { await homeViewModel.loadDashboardSummary() }
    }
}

extension HomeView: Equatable {
    static func == (lhs: HomeView, rhs: HomeView) -> Bool {
        lhs.tabBarState === rhs.tabBarState
    }
}

private struct FoodSectionView: View {
    @Bindable var todayFoodVM: TodayFoodViewModel
    let onAddFood: () -> Void
    let onScan: () -> Void
    let onEditFood: (FoodEntry) -> Void
    let onDeleteFood: (String) -> Void
    
    var body: some View {
        FoodSection(
            todayFoodVM: todayFoodVM,
            onAddFood: onAddFood,
            onScan: onScan,
            onEditFood: onEditFood,
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

#Preview {
    HomePreviewContent()
}

private struct HomePreviewContent: View {
    var body: some View {
        return HomeView(
            homeViewModel: makePreviewHomeVM(),
            foodService: MockFoodService(),
            coordinator: AppCoordinator(container: AppDependencyContainer())
        )
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
    }
    
    private func makePreviewHomeVM() -> HomeViewModel {
        let coordinator = AppCoordinator(container: AppDependencyContainer())
        let todayFoodVM = TodayFoodViewModel(service: MockFoodService(), coordinator: coordinator)
        todayFoodVM.setPreviewState(.loaded([
            FoodEntry(id: "1", userId: "1", name: "Chicken", calories: 165, protein: 31, fat: 4, carbs: 0, foodId: nil, grams: nil, unit: "g", categoryName: nil, imageUrl: nil, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil),
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
