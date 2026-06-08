import Foundation

struct NeverBody: Encodable,Sendable {}

struct APIRequest<Body: Encodable & Sendable>: Sendable {
    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]
    let body: Body?
    let headers: [String: String]

    init(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        body: Body? = nil,
        headers: [String: String] = [:]
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.body = body
        self.headers = headers
    }
}
