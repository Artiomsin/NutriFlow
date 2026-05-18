import SwiftUI

struct HomeView: View {

    @EnvironmentObject var session: SessionManager
    var onLogout: (() -> Void)?
    @ObservedObject var profileViewModel: ProfileViewModel

    @State private var selectedTab = 0

    var body: some View {

        ZStack {

            AppTheme.background.ignoresSafeArea()

TabView(selection: $selectedTab) {

                HomeTabFlow()
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
    let vm = ProfileViewModel(
        session: session,
        profileService: MockProfileService(),
        userService: MockUserService()
    )

    HomeViewPreviewWrapper(
        vm: vm,
        session: session
    )
    .environmentObject(session)
    .preferredColorScheme(.dark)
}

struct HomeViewPreviewWrapper: View {
    let vm: ProfileViewModel
    let session: SessionManager

    var body: some View {
        HomeView(
            onLogout: {},
            profileViewModel: vm
        )
        .onAppear {
            vm.email = "test@example.com"
            vm.firstName = "Artem"
            vm.lastName = "Developer"
            vm.weight = "82"
            vm.height = "183"
            vm.age = "24"
            vm.goal = .gain
            vm.activityLevel = .high
            vm.setPreviewState(.loaded(UserProfile(
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
        }
    }
}

