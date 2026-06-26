import Foundation

enum GuestError: LocalizedError {
    case registrationRequired
    case migrationFailed(String)
    case operationNotAvailable

    var errorDescription: String? {
        switch self {
        case .registrationRequired:
            return "Register an account to use this feature"
        case .migrationFailed(let detail):
            return "Failed to sync guest data: \(detail)"
        case .operationNotAvailable:
            return "Not available in guest mode"
        }
    }
}
