import SwiftUI

struct AppRootView: View {
    
    @StateObject private var session = SessionManager()
    
    var body: some View {
        
        ZStack {
            
            Color(red: 0.03, green: 0.04, blue: 0.06)
                .ignoresSafeArea()
            
            switch session.state {
                
            case .loading:
                ProgressView()
                
            case .unauthenticated:
                AuthView(
                    vm: AuthViewModel(session: session)
                )
                
            case .authenticated:
                HomeView()
                    .environmentObject(session)
            }
        }
    }
}

#Preview {
    AppRootView()
}
