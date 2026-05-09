import Foundation

final class AuthService {
    
    private let client = APIClient.shared
    
    func login(email: String, password: String) async throws -> AuthResponse {
        
        let body = try JSONEncoder().encode(
            LoginRequest(email: email, password: password)
        )
        
        return try await client.request(
            endpoint: "/auth/login",
            method: "POST",
            body: body
        )
    }
    
    func refresh(token: String) async throws -> AuthResponse {
        
        let body = try JSONEncoder().encode([
            "refreshToken": token
        ])
        
        return try await client.request(
            endpoint: "/auth/refresh",
            method: "POST",
            body: body
        )
    }
    
    func register(email: String, password: String, firstName: String, lastName: String) async throws -> AuthResponse {
        
        let body = try JSONEncoder().encode(
            RegisterRequest(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName
            )
        )
        
        return try await client.request(
            endpoint: "/auth/register",
            method: "POST",
            body: body
        )
    }
    
    func logout(token: String) async throws -> LogoutResponse {
        return try await client.request(
            endpoint: "/auth/logout",
            method: "POST",
            body: nil,
            token: token
        )
    }
}
