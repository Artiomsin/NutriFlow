import Foundation

struct APIRequest<Body: Encodable> {

    let path: String
    let method: HTTPMethod
    let body: Body?
    let headers: [String: String]

    init(
        path: String,
        method: HTTPMethod,
        body: Body? = nil,
        headers: [String: String] = [:]
    ) {
        self.path = path
        self.method = method
        self.body = body
        self.headers = headers
    }
}
