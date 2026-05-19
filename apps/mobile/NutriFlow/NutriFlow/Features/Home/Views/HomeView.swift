import SwiftUI

struct HomeView: View {

    @EnvironmentObject var session: SessionManager
    var onLogout: (() -> Void)?
    @ObservedObject var profileViewModel: ProfileViewModel
    @ObservedObject var foodViewModel: FoodViewModel

    @State private var selectedTab = 0

    var body: some View {

        ZStack {

            AppTheme.background.ignoresSafeArea()

TabView(selection: $selectedTab) {

                HomeTabFlow(
                    foodViewModel: foodViewModel
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

            CustomTabBar(selectedTab: $selectedTab)
                .padding(.bottom, 20)
                .frame(maxHeight: .infinity, alignment: .bottom)
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

    HomeViewPreviewWrapper(
        profileVM: profileVM,
        foodVM: foodVM,
        session: session
    )
    .environmentObject(session)
    .preferredColorScheme(.dark)
}

struct HomeViewPreviewWrapper: View {
    let profileVM: ProfileViewModel
    let foodVM: FoodViewModel
    let session: SessionManager

    var body: some View {
        HomeView(
            onLogout: {},
            profileViewModel: profileVM,
            foodViewModel: foodVM
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

