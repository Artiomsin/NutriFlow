import Foundation

protocol HTTPClient: Sendable {
    func send<T: Decodable & Sendable, Body: Encodable & Sendable>(
        _ request: APIRequest<Body>
    ) async throws -> T

    func sendVoid<Body: Encodable & Sendable>(
        _ request: APIRequest<Body>
    ) async throws

    func sendUpload(data: Data, fileName: String, mimeType: String, path: String) async throws -> String
}
