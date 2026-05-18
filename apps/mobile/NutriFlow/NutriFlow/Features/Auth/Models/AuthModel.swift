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

struct EmptyBody: Encodable {}

struct AuthTokensResponse: Decodable {
    let accessToken: String
    let refreshToken: String
}

struct LogoutResponse: Decodable {
    let message: String
}

struct EmptyResponse: Decodable {}

struct User: Decodable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
}
