
import Foundation

@MainActor
final class SessionManager: ObservableObject {
    
    @Published private(set) var state: AuthState = .loading
    
    private let authService = AuthService()
    
    init() {
        Task {
            await restoreSession()
        }
    }
    
    func restoreSession() async {
        
        guard let refresh = TokenStorage.shared.getRefresh(),
              !refresh.isEmpty else {
            state = .unauthenticated
            return
        }
        
        do {
            
            let res = try await authService.refresh(token: refresh)
            
            TokenStorage.shared.save(
                access: res.accessToken,
                refresh: res.refreshToken
            )
            
            state = .authenticated
            
        } catch {
            
            TokenStorage.shared.clear()
            state = .unauthenticated
        }
    }
    
    func login(access: String, refresh: String) {
        
        TokenStorage.shared.save(access: access, refresh: refresh)
        state = .authenticated
    }
    
    func logout() {
        
        TokenStorage.shared.clear()
        state = .unauthenticated
    }
}
