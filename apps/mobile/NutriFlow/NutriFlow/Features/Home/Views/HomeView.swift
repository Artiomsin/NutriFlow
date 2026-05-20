import SwiftUI

struct HomeView: View {

    var onLogout: (() -> Void)?
    
    @Bindable var homeViewModel: HomeViewModel
    @Bindable var profileViewModel: ProfileViewModel
    @Bindable var session: SessionManager

    @State private var selectedTab = 0

    var body: some View {

        TabView(selection: $selectedTab) {

            HomeTabFlow(homeViewModel: homeViewModel, session: session)
                .tag(0)

            ProfileTabFlow(
                profileViewModel: profileViewModel, session: session,
                onLogout: onLogout
            )
            .tag(1)
            StatisticsTabFlow(dailyViewModel: homeViewModel.dailyViewModel, session: session).tag(2)
            
            SettingsTabFlow(session: session)
                .tag(3)
        }
        .toolbar(.hidden, for: .tabBar)
        .background(AppTheme.background)
        .safeAreaInset(edge: .bottom) {
            CustomTabBar(selectedTab: $selectedTab)
                .background(AppTheme.background)
        }
    }
}


#Preview {
    HomePreviewContent()
}
struct HomePreviewContent: View {
    var body: some View {
        let session = SessionManager(tokenStorage: TokenStorage(keychain: KeychainService()))
        
        let profileVM = ProfileViewModel(
            session: session,
            profileService: MockProfileService(),
            userService: MockUserService()
        )
        profileVM.email = "test@example.com"
        profileVM.firstName = "Artem"
        profileVM.lastName = "Developer"
        profileVM.weight = "82"
        profileVM.height = "183"
        profileVM.age = "24"
        profileVM.goal = .gain
        profileVM.activityLevel = .high
        profileVM.setPreviewState(.loaded(UserProfile(
            id: UUID().uuidString,
            userId: UUID().uuidString,
            email: "test@example.com",
            firstName: "Artem",
            lastName: "Developer",
            weight: 82,
            height: 183,
            age: 24,
            goal: .gain,
            activityLevel: .high,
            createdAt: nil,
            updatedAt: nil
        )))
        
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
            date: "2026-05-20",
            totalCalories: 1250,
            totalProtein: 85,
            totalFat: 42,
            totalCarbs: 120,
            totalWaterMl: 1750,
            createdAt: "2026-05-20T10:00:00Z",
            updatedAt: nil
        )))
        
        dailyVM.chartData = [
            ChartDataPoint(date: Date(), label: "05/20", calories: 1800, protein: 80, fat: 60, carbs: 200, waterMl: 2000),
            ChartDataPoint(date: Date().addingTimeInterval(-86400), label: "05/19", calories: 1650, protein: 75, fat: 55, carbs: 190, waterMl: 1800),
            ChartDataPoint(date: Date().addingTimeInterval(-2*86400), label: "05/18", calories: 2000, protein: 90, fat: 70, carbs: 220, waterMl: 2200),
            ChartDataPoint(date: Date().addingTimeInterval(-3*86400), label: "05/17", calories: 1500, protein: 70, fat: 50, carbs: 180, waterMl: 1500),
            ChartDataPoint(date: Date().addingTimeInterval(-4*86400), label: "05/16", calories: 1750, protein: 85, fat: 65, carbs: 195, waterMl: 1900),
            ChartDataPoint(date: Date().addingTimeInterval(-5*86400), label: "05/15", calories: 1900, protein: 95, fat: 75, carbs: 210, waterMl: 2100),
            ChartDataPoint(date: Date().addingTimeInterval(-6*86400), label: "05/14", calories: 1600, protein: 78, fat: 58, carbs: 185, waterMl: 1700)
        ]
        dailyVM.chartState = .loaded(dailyVM.chartData)
        dailyVM.daysCount = 7
        dailyVM.totalCaloriesSum = 12200
        dailyVM.totalWaterSum = 13200
        dailyVM.avgProtein = 82
        dailyVM.avgFat = 62
        dailyVM.avgCarbs = 197
        
        let homeVM = HomeViewModel(
            foodViewModel: foodVM,
            waterViewModel: waterVM,
            dailyViewModel: dailyVM
        )
        return HomeView(
            onLogout: {},
            homeViewModel: homeVM,
            profileViewModel: profileVM,
            session: session
        )
        .preferredColorScheme(.dark)
    }
}


