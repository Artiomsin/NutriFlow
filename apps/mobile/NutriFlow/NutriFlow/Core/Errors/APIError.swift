import Foundation

/// Transport-level failures produced by `URLSessionHTTPClient`.
///
/// A response that carries a Problem Details body becomes `.remote`. The
/// status-based cases are the fallback for responses without that body (proxy
/// HTML error pages, empty 502s, truncated JSON), so they are not duplicates
/// of `.remote`; each one is still constructed by `validate(data:response:)`.
enum APIError: Error, Equatable, Sendable {
    case remote(ProblemDetails, retryAfter: TimeInterval?)
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
    case cancelled
    case unknown
}

extension APIError: AppErrorConvertible {
    /// Field-level problems are preserved from the Problem Details body so a
    /// form can render them under the offending input instead of collapsing
    /// them into a generic request error.
    var fieldErrors: [FieldProblem] {
        guard case .remote(let problem, _) = self else { return [] }
        return problem.fieldErrors
    }

    var appError: AppError {
        switch self {
        case .remote(let problem, _):
            return Self.appError(for: problem)
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
        case .requestFailed:
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
        case .remote(let problem, _):
            return problem.status
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
        case .invalidURL, .transport, .requestFailed, .encodingFailed, .decodingFailed, .cancelled, .unknown:
            return nil
        }
    }

    var requestId: String? {
        switch self {
        case .remote(let problem, _):
            return problem.requestId
        case .invalidRequest(_, let requestId),
             .conflict(let requestId),
             .requestTimeout(let requestId),
             .rateLimited(let requestId),
             .serverError(_, let requestId),
             .http(_, let requestId):
            return requestId
        case .invalidURL, .unauthorized, .forbidden, .notFound, .transport,
             .requestFailed, .encodingFailed, .decodingFailed, .cancelled, .unknown:
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

    private static func appError(for problem: ProblemDetails) -> AppError {
        switch problem.problemType {
        case .foodAnalysisQuotaExceeded:
            return .foodAnalysisQuotaExceeded
        case .validationFailed, .invalidRequest:
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
        case .serverError, .serviceUnavailable:
            return .serverUnavailable
        case nil:
            return appError(forHTTPStatus: problem.status)
        }
    }
}
