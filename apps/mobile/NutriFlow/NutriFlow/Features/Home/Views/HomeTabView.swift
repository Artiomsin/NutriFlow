import SwiftUI

struct HomeTabView: View {
    
    @EnvironmentObject var session: SessionManager
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                
                VStack(spacing: 6) {
                    
                    Text("Home")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(.top, AppTheme.headerPaddingTop)
                    
                    Text("Welcome back")
                        .font(.footnote)
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                Spacer()
                    .frame(height: 20)
                
                VStack(spacing: 16) {
                    
                    AppCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Today")
                                .font(.headline)
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Text("Your nutrition overview will appear here")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    
                    AppCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Progress")
                                .font(.headline)
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Text("Track your daily goals")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.paddingHorizontal)
                
                Spacer()
                    .frame(height: 100)
            }
            .background(AppTheme.background)
        }
    }
}

#Preview {
    let session = SessionManager(tokenStorage: TokenStorage(keychain: KeychainService()))
    return HomeTabView()
        .environmentObject(session)
        .preferredColorScheme(.dark)
}
