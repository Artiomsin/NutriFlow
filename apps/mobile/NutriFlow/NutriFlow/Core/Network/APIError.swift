import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case networkError(Error)
    case unauthorized
    case badRequest(String?)
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(_, let message):
            return message ?? "Request failed"
        case .decodingError:
            return "Failed to parse response"
        case .networkError:
            return "Network connection failed"
        case .unauthorized:
            return "Session expired. Please log in again"
        case .badRequest(let message):
            return message ?? "Invalid request"
        case .serverError(let code):
            return "Server error (\(code))"
        }
    }
}