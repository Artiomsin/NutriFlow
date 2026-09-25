import Foundation

enum AuthOperation: Equatable {
    case credentials
    case google
    case apple
}

enum AuthState: Equatable {
    case idle
    case loading
    case authenticated
    case unauthenticated
    case error(AppError, operation: AuthOperation)
}