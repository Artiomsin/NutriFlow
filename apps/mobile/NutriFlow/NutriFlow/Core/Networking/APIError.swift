import Foundation

enum APIError: Error, Equatable, Sendable {
    case invalidURL
    case invalidRequest(statusCode: Int, requestId: String?)
    case unauthorized
    case forbidden
    case notFound
    case conflict(requestId: String?)
    case requestTimeout(requestId: String?)
    case rateLimited(requestId: String?)
    case serverError(statusCode: Int, requestId: String?)
    case http(statusCode: Int, requestId: String?)
    case transport(code: URLError.Code)
    case requestFailed
    case encodingFailed
    case decodingFailed
    case noData
    case cancelled
    case unknown
}

extension APIError: AppErrorConvertible {
    var appError: AppError {
        switch self {
        case .invalidURL, .invalidRequest, .encodingFailed:
            return .invalidRequest
        case .unauthorized:
            return .unauthorized
        case .forbidden:
            return .forbidden
        case .notFound:
            return .notFound
        case .conflict:
            return .conflict
        case .requestTimeout:
            return .timeout
        case .rateLimited:
            return .rateLimited
        case .serverError:
            return .serverUnavailable
        case .http(let statusCode, _):
            return Self.appError(forHTTPStatus: statusCode)
        case .transport(let code):
            return ErrorMapper.map(URLError(code))
        case .requestFailed, .noData:
            return .invalidResponse
        case .decodingFailed:
            return .decoding
        case .cancelled:
            return .cancelled
        case .unknown:
            return .unknown
        }
    }

    var statusCode: Int? {
        switch self {
        case .invalidRequest(let statusCode, _):
            return statusCode
        case .unauthorized:
            return 401
        case .forbidden:
            return 403
        case .notFound:
            return 404
        case .conflict:
            return 409
        case .requestTimeout:
            return 408
        case .rateLimited:
            return 429
        case .serverError(let statusCode, _), .http(let statusCode, _):
            return statusCode
        case .invalidURL, .transport, .requestFailed, .encodingFailed, .decodingFailed, .noData, .cancelled, .unknown:
            return nil
        }
    }

    var requestId: String? {
        switch self {
        case .invalidRequest(_, let requestId),
             .conflict(let requestId),
             .requestTimeout(let requestId),
             .rateLimited(let requestId),
             .serverError(_, let requestId),
             .http(_, let requestId):
            return requestId
        case .invalidURL, .unauthorized, .forbidden, .notFound, .transport,
             .requestFailed, .encodingFailed, .decodingFailed, .noData, .cancelled, .unknown:
            return nil
        }
    }

    private static func appError(forHTTPStatus statusCode: Int) -> AppError {
        switch statusCode {
        case 400, 422:
            return .invalidRequest
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 408:
            return .timeout
        case 409:
            return .conflict
        case 429:
            return .rateLimited
        case 500...599:
            return .serverUnavailable
        default:
            return .unknown
        }
    }
}
