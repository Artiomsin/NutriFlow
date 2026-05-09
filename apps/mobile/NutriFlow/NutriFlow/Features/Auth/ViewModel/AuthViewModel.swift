import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    
    @Published var email = ""
    @Published var password = ""
    @Published var firstName = ""
    @Published var lastName = ""
    
    @Published var state: AuthState = .loading
    @Published var errorMessage: String?
    
    private let service = AuthService()
    
    init() {
        Task {
            await restoreSession()
        }
    }

    func restoreSession() async {
        
        
        guard let refresh = TokenStorage.shared.getRefresh(),
              !refresh.isEmpty else {
            state = .loggedOut
            return
        }
        
        do {
        
            let res = try await service.refresh(token: refresh)
            
            print("REFRESH SUCCESS")
            print("NEW ACCESS:", res.accessToken)
            print("NEW REFRESH:", res.refreshToken)
            
           
            TokenStorage.shared.save(
                access: res.accessToken,
                refresh: res.refreshToken
            )
            
            
            state = .loggedIn
            
        } catch {
            print("REFRESH FAILED:", error)
            
            
            TokenStorage.shared.clear()
            state = .loggedOut
        }
    }

    func login() async {
        errorMessage = nil
        
        do {
            let res = try await service.login(email: email, password: password)

            print("ACCESS:", res.accessToken)
            print("REFRESH:", res.refreshToken)

            TokenStorage.shared.save(access: res.accessToken, refresh: res.refreshToken)

            state = .loggedIn

        } catch {
            errorMessage = error.localizedDescription
            state = .loggedOut
        }
    }

    func register() async {
        errorMessage = nil
        
        do {
            let res = try await service.register(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName
            )

            print("ACCESS:", res.accessToken)
            print("REFRESH:", res.refreshToken)

            TokenStorage.shared.save(access: res.accessToken, refresh: res.refreshToken)

            state = .loggedIn

        } catch {
            errorMessage = error.localizedDescription
            state = .loggedOut
        }
    }

    func logout() async {
        guard let token = TokenStorage.shared.getAccess() else {
            state = .loggedOut
            return
        }

        do {
            _ = try await service.logout(token: token)
        } catch {
            print("Logout error:", error)
        }

        TokenStorage.shared.clear()
        state = .loggedOut
    }
}
