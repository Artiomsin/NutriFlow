import Foundation

enum AuthState {
    case idle
    case loading
    case authenticated
    case unauthenticated
    case error(String)
}
