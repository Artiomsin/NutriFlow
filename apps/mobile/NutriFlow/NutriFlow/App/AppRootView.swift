
import SwiftUI

struct AppRootView: View {
    
    @StateObject private var authVM = AuthViewModel()
    
    var body: some View {
        
        ZStack {
            
           
            Color(red: 0.03, green: 0.04, blue: 0.06)
                .ignoresSafeArea()
            
            
            
            Group {
                switch authVM.state {
                    
                case .loading:
                    ProgressView()
                    
                case .loggedOut:
                    AuthView()
                        .environmentObject(authVM)
                    
                case .loggedIn:
                    HomeView()
                        .environmentObject(authVM)
                        
                }
            }
        }
    }
}
#Preview {
    AppRootView()
}
