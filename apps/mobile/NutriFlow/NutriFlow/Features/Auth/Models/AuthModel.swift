import Foundation

struct LoginDTO: Encodable, Sendable {
    let email: String
    let password: String
}

struct RegisterDTO: Encodable, Sendable {
    let email: String
    let password: String
    let firstName: String
    let lastName: String
}

struct GoogleLoginDTO: Encodable, Sendable {
    let idToken: String
}

struct RefreshDTO: Encodable, Sendable {
    let refreshToken: String
}

struct AuthTokensResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
}

struct User: Decodable, Sendable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
}
