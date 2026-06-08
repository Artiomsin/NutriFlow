import Foundation

struct LoginDTO: Encodable {
    let email: String
    let password: String
}

struct RegisterDTO: Encodable {
    let email: String
    let password: String
    let firstName: String
    let lastName: String
}

struct RefreshDTO: Encodable {
    let refreshToken: String
}

struct AuthTokensResponse: Decodable {
    let accessToken: String
    let refreshToken: String
}

struct User: Decodable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
}
