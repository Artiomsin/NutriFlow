import Foundation

enum APIError: Error {
    case invalidURL
    case requestFailed
    case unauthorized
    case forbidden
    case notFound
    case decodingFailed
    case serverError(statusCode: Int)
    case noData
    case unknown
}
