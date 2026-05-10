import SwiftUI

struct HomeView: View {
    
    @EnvironmentObject var session: SessionManager
    
    @State private var selectedTab = 0
    @GestureState private var dragOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.04, blue: 0.06)
                .ignoresSafeArea()
            
            TabView(selection: $selectedTab) {
                HomeTabView()
                    .tag(0)
                
                ProfileTabView()
                    .environmentObject(session)
                    .tag(1)
                
                SettingsView()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        if value.translation.width > threshold, selectedTab > 0 {
                            withAnimation {
                                selectedTab -= 1
                            }
                        } else if value.translation.width < -threshold, selectedTab < 2 {
                            withAnimation {
                                selectedTab += 1
                            }
                        }
                    }
            )
            
            VStack {
                Spacer()
                CustomTabBar(selectedTab: $selectedTab)
                    .padding(.bottom, 20)
            }
        }
    }
}

struct HomeTabView: View {
    
    @EnvironmentObject var session: SessionManager
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                
                VStack(spacing: 6) {
                    
                    Text("Home")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 60)
                    
                    Text("Welcome back")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                    .frame(height: 20)
                
                VStack(spacing: 16) {
                    
                    AppCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Today")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Your nutrition overview will appear here")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    
                    AppCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Progress")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Track your daily goals")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                    .frame(height: 100)
            }
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

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(icon: "house", title: "Home", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            
            TabBarButton(icon: "person", title: "Profile", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            
            TabBarButton(icon: "gearshape", title: "Settings", isSelected: selectedTab == 2) {
                selectedTab = 2
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(red: 0.05, green: 0.06, blue: 0.08))
        .cornerRadius(20)
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .green : .white.opacity(0.4))
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .green : .white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
        }
    }
}