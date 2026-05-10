import Foundation

enum AuthState: Equatable {
    case loading
    case authenticated
    case unauthenticated
    case error(Error)
    
    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case (.authenticated, .authenticated):
            return true
        case (.unauthenticated, .unauthenticated):
            return true
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}
