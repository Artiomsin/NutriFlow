import SwiftUI

struct HomeView: View {
    
    @EnvironmentObject var vm: AuthViewModel
    
    var body: some View {
        ZStack {
            
            Color(red: 0.03, green: 0.04, blue: 0.06)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                
                VStack(spacing: 6) {
                    
                    Text("Home")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Welcome back")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.top, 60)
                
                Spacer()
                
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
                
                PrimaryButton(title: "Logout") {
                    Task {
                        await vm.logout()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
    }
}

#Preview {
    let testVM = AuthViewModel()
    testVM.state = .loggedIn
    return HomeView()
        .environmentObject(testVM)
}
