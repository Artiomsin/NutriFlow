import Foundation

enum APIError: Error, Equatable {
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
