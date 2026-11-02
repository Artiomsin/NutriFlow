enum AuthOperation {
    case login
    case register
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
