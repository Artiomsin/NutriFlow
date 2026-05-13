import SwiftUI

struct HomeView: View {

    @EnvironmentObject var session: SessionManager
    var onLogout: (() -> Void)?
    @ObservedObject var profileViewModel: ProfileViewModel

    @State private var selectedTab = 0

    var body: some View {

        ZStack {

            Color(red: 0.03, green: 0.04, blue: 0.06)
                .ignoresSafeArea()

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

        NavigationStack {
            Color(red: 0.03, green: 0.04, blue: 0.06)
                .ignoresSafeArea()
                .overlay(SettingsView())
        }
    }
}

struct SettingsView: View {
    
    @EnvironmentObject var session: SessionManager
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                
                Text("Settings")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.top, 60)
                
                Spacer()
                    .frame(height: 20)
                
                VStack(spacing: 16) {
                    SettingsRow(icon: "person", title: "Account")
                    SettingsRow(icon: "bell", title: "Notifications")
                    SettingsRow(icon: "lock", title: "Privacy")
                }
                .padding(.horizontal, 20)
                
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
                .font(.system(size: 20))
                .foregroundColor(.green)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

