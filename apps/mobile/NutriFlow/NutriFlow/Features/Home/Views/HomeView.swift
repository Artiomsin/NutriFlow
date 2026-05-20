import SwiftUI

struct HomeView: View {

    @EnvironmentObject var session: SessionManager

    var onLogout: (() -> Void)?

    @ObservedObject var profileViewModel: ProfileViewModel
    @ObservedObject var foodViewModel: FoodViewModel
    @ObservedObject var waterViewModel: WaterViewModel
    @ObservedObject var dailyViewModel: DailySummaryViewModel

    @State private var selectedTab = 0

    var body: some View {

        TabView(selection: $selectedTab) {

            HomeTabFlow(
                foodViewModel: foodViewModel,
                waterViewModel: waterViewModel,
                dailyViewModel: dailyViewModel
            )
            .environmentObject(session)
            .tag(0)

            ProfileTabFlow(
                profileViewModel: profileViewModel,
                onLogout: onLogout
            )
            .environmentObject(session)
            .tag(1)

            SettingsTabFlow()
                .environmentObject(session)
                .tag(2)
        }
        .toolbar(.hidden, for: .tabBar)
        .background(AppTheme.background)
        .safeAreaInset(edge: .bottom) {

            CustomTabBar(selectedTab: $selectedTab)
                .background(AppTheme.background)
        }
    }
}




struct SettingsTabFlow: View {

    @EnvironmentObject var session: SessionManager

    var body: some View {
        AppTheme.background.ignoresSafeArea()
            .overlay(SettingsView())
    }
}

struct SettingsView: View {
    
    @EnvironmentObject var session: SessionManager
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                
                Text("Settings")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.top, AppTheme.headerPaddingTop)
                
                Spacer()
                    .frame(height: 20)
                
                VStack(spacing: 16) {
                    SettingsRow(icon: "person", title: "Account")
                    SettingsRow(icon: "bell", title: "Notifications")
                    SettingsRow(icon: "lock", title: "Privacy")
                }
                .padding(.horizontal, AppTheme.paddingHorizontal)
                
                Spacer()
                    .frame(height: 100)
            }
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: AppTheme.iconSize))
                .foregroundColor(AppTheme.accent)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppTheme.textPrimary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
}




#Preview {
    let session = SessionManager(tokenStorage: TokenStorage(keychain: KeychainService()))
    let profileVM = ProfileViewModel(
        session: session,
        profileService: MockProfileService(),
        userService: MockUserService()
    )
    let foodVM = FoodViewModel(
        session: session,
        service: MockFoodService()
    )
    let waterVM = WaterViewModel(
        session: session,
        service: MockWaterService()
    )
    let dailyVM = DailySummaryViewModel(
        session: session,
        service: MockDailySummaryService()
    )

    HomeViewPreviewWrapper(
        profileVM: profileVM,
        foodVM: foodVM,
        waterVM: waterVM,
        dailyVM: dailyVM,
        session: session
    )
    .environmentObject(session)
    .preferredColorScheme(.dark)
}

struct HomeViewPreviewWrapper: View {
    let profileVM: ProfileViewModel
    let foodVM: FoodViewModel
    let waterVM: WaterViewModel
    let dailyVM: DailySummaryViewModel
    let session: SessionManager

    var body: some View {
        HomeView(
            onLogout: {},
            profileViewModel: profileVM,
            foodViewModel: foodVM,
            waterViewModel: waterVM,
            dailyViewModel: dailyVM
        )
        .onAppear {
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
            foodVM.setPreviewState(.loaded([
                FoodEntry(id: "1", userId: "1", name: "Chicken breast", calories: 165, protein: 31, fat: 4, carbs: 0, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil),
                FoodEntry(id: "2", userId: "1", name: "Rice", calories: 200, protein: 4, fat: 1, carbs: 45, createdAt: "2026-05-18T12:00:00Z", updatedAt: nil)
            ]))
            waterVM.setPreviewState(.loaded([
                WaterEntry(id: "1", userId: "1", amountMl: 250, createdAt: "2026-05-18T08:00:00Z", updatedAt: nil),
                WaterEntry(id: "2", userId: "1", amountMl: 500, createdAt: "2026-05-18T10:30:00Z", updatedAt: nil)
            ]))
        }
    }
}

final class MockFoodService: FoodServiceProtocol {
    func createFoodEntry(token: String, name: String, calories: Int, protein: Int?, fat: Int?, carbs: Int?) async throws -> FoodEntry {
        FoodEntry(id: UUID().uuidString, userId: "1", name: name, calories: calories, protein: protein, fat: fat, carbs: carbs, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil)
    }
    func getTodayFood(token: String) async throws -> [FoodEntry] {
        [
            FoodEntry(id: "1", userId: "1", name: "Chicken breast", calories: 165, protein: 31, fat: 4, carbs: 0, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil),
            FoodEntry(id: "2", userId: "1", name: "Rice", calories: 200, protein: 4, fat: 1, carbs: 45, createdAt: "2026-05-18T12:00:00Z", updatedAt: nil)
        ]
    }
    func deleteFoodEntry(token: String, id: String) async throws -> EmptyResponse {
        EmptyResponse()
    }
}

final class MockWaterService: WaterTrackingServiceProtocol {
    func createWaterEntry(token: String, amountMl: Int) async throws -> WaterEntry {
        WaterEntry(id: UUID().uuidString, userId: "1", amountMl: amountMl, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil)
    }
    func getTodayWater(token: String) async throws -> [WaterEntry] {
        [
            WaterEntry(id: "1", userId: "1", amountMl: 250, createdAt: "2026-05-18T08:00:00Z", updatedAt: nil),
            WaterEntry(id: "2", userId: "1", amountMl: 500, createdAt: "2026-05-18T10:30:00Z", updatedAt: nil)
        ]
    }
    func deleteWaterEntry(token: String, id: String) async throws -> EmptyResponse {
        EmptyResponse()
    }
}

final class MockDailySummaryService: DailySummaryServiceProtocol {
    func getTodayDailySummary(token: String) async throws -> DailySummary {
        DailySummary(
            id: "1",
            userId: "1",
            date: "2026-05-18",
            totalCalories: 365,
            totalProtein: 35,
            totalFat: 5,
            totalCarbs: 45,
            totalWaterMl: 750,
            createdAt: "2026-05-18T10:00:00Z",
            updatedAt: nil
        )
    }
    func getDailySummaryByDate(token: String, date: String) async throws -> DailySummary {
        try await getTodayDailySummary(token: token)
    }
    func getDailySummaryRange(token: String, from: String, to: String) async throws -> [DailySummary] {
        [try await getTodayDailySummary(token: token)]
    }
}

