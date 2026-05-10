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
    
    
    var accessToken: String? {
        TokenStorage.shared.getAccess()
    }
    
    var refreshToken: String? {
        TokenStorage.shared.getRefresh()
    }
    
    var userEmail: String? {
        TokenStorage.shared.getEmail()
    }
    
    var userFirstName: String? {
        TokenStorage.shared.getFirstName()
    }
    
    var userLastName: String? {
        TokenStorage.shared.getLastName()
    }
    
    
    func restoreSession() async {
        
        guard let refresh = refreshToken,
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
    
    
    func login(access: String, refresh: String, email: String? = nil, firstName: String? = nil, lastName: String? = nil) {
        
        TokenStorage.shared.save(access: access, refresh: refresh)
        TokenStorage.shared.saveUserData(email: email, firstName: firstName, lastName: lastName)
        state = .authenticated
    }
    
    func logout() {
        
        TokenStorage.shared.clear()
        state = .unauthenticated
    }
}