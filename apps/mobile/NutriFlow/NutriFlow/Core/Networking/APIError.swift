import Foundation

enum APIError: Error, Equatable, Sendable {
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

extension APIError {
    var analyzeStatusCode: Int? {
        if case .serverError(let code) = self {
            return code
        }
        return nil
    }
}
