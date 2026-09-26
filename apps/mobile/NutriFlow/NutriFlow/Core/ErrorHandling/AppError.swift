import Foundation

enum AppError: Error, Equatable, Sendable {
    case offline
    case timeout
    case secureConnectionFailed
    case unauthorized
    case sessionExpired
    case forbidden
    case notFound
    case conflict
    case rateLimited
    case serverUnavailable
    case invalidRequest
    case invalidResponse
    case decoding
    case validation(message: String)
    case partialSave(succeeded: Int, total: Int, failedNames: [String])
    case permissionDenied
    case storage
    case cancelled
    case unknown
}

protocol AppErrorConvertible {
    var appError: AppError { get }
}
