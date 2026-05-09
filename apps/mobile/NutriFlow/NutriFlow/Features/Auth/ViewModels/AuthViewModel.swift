import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    
    
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    
    
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let authService: AuthService
    private let session: SessionManager
    
    
    init(
        session: SessionManager,
        authService: AuthService = AuthService()
    ) {
        self.session = session
        self.authService = authService
    }
    
    
    func login() async {
        
        guard validateLogin() else { return }
        
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            
            let response = try await authService.login(
                email: email,
                password: password
            )
            
            session.login(
                access: response.accessToken,
                refresh: response.refreshToken
            )
            
            clearInputs()
            
        } catch {
            errorMessage = mapError(error)
        }
    }
    
    
    func register() async {
        
        guard validateRegister() else { return }
        
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            
            let response = try await authService.register(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName
            )
            
            session.login(
                access: response.accessToken,
                refresh: response.refreshToken
            )
            
            clearInputs()
            
        } catch {
            errorMessage = mapError(error)
        }
    }
    
    
    func logout() {
        session.logout()
        clearInputs()
    }
}


private extension AuthViewModel {
    
    func validateLogin() -> Bool {
        
        if email.isEmpty || password.isEmpty {
            errorMessage = "Email and password are required"
            return false
        }
        
        return true
    }
    
    func validateRegister() -> Bool {
        
        if email.isEmpty ||
            password.isEmpty ||
            firstName.isEmpty ||
            lastName.isEmpty {
            
            errorMessage = "All fields are required"
            return false
        }
        
        return true
    }
}


private extension AuthViewModel {
    
    func clearInputs() {
        email = ""
        password = ""
        firstName = ""
        lastName = ""
    }
    
    func mapError(_ error: Error) -> String {
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "No internet connection"
            case .timedOut:
                return "Request timed out"
            default:
                return "Network error"
            }
        }
        
        return error.localizedDescription
    }
}
