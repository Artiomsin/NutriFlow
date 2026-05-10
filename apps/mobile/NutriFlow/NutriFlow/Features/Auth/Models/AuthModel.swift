import Foundation

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let firstName: String
    let lastName: String
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let email: String?
    let firstName: String?
    let lastName: String?
}

struct LogoutResponse: Codable {
    let message: String
}
