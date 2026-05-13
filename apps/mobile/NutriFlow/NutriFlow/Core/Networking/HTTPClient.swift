import Foundation

protocol HTTPClient {
    func send<T: Decodable, Body: Encodable>(
        _ request: APIRequest<Body>
    ) async throws -> T
}
