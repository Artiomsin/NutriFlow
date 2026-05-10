import Foundation

enum ValidationError: LocalizedError {
    case emptyField(String)
    case invalidEmail

    var errorDescription: String? {
        switch self {
        case .emptyField(let field):
            return "\(field) is required"
        case .invalidEmail:
            return "Invalid email format"
        }
    }
}

@MainActor
final class AuthViewModel: ObservableObject {
    
    @Published var state: AuthState = .unauthenticated
    
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    
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
        
        state = .loading
        
        do {
            let response = try await authService.login(
                email: email,
                password: password
            )
            
            session.login(
                access: response.accessToken,
                refresh: response.refreshToken,
                email: email
            )
            
            clearInputs()
            state = .authenticated
            
        } catch {
            state = .error(error)
        }
    }
    
    
    func register() async {
        
        guard validateRegister() else { return }
        
        state = .loading
        
        do {
            let response = try await authService.register(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName
            )
            
            session.login(
                access: response.accessToken,
                refresh: response.refreshToken,
                email: response.email ?? email,
                firstName: response.firstName ?? firstName,
                lastName: response.lastName ?? lastName
            )
            
            clearInputs()
            state = .authenticated
            
        } catch {
            state = .error(error)
        }
    }
    
    
    func logout() {
        
        session.logout()
        clearInputs()
        state = .unauthenticated
    }
    
    private func validateLogin() -> Bool {
        
        guard !email.isEmpty else {
            state = .error(ValidationError.emptyField("Email"))
            return false
        }
        
        guard !password.isEmpty else {
            state = .error(ValidationError.emptyField("Password"))
            return false
        }
        
        return true
    }
    
    private func validateRegister() -> Bool {
        
        guard !email.isEmpty else {
            state = .error(ValidationError.emptyField("Email"))
            return false
        }
        
        guard !password.isEmpty else {
            state = .error(ValidationError.emptyField("Password"))
            return false
        }
        
        guard !firstName.isEmpty else {
            state = .error(ValidationError.emptyField("First name"))
            return false
        }
        
        guard !lastName.isEmpty else {
            state = .error(ValidationError.emptyField("Last name"))
            return false
        }
        
        return true
    }
    
    
    private func clearInputs() {
        email = ""
        password = ""
        firstName = ""
        lastName = ""
    }
}