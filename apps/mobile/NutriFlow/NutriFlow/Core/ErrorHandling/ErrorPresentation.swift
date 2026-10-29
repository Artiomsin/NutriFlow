import Foundation

struct ErrorPresentation: Equatable {
    let title: String
    let message: String
    let allowsRetry: Bool

    init(error: AppError) {
        switch error {
        case .offline:
            title = String(localized: "error.offline.title", defaultValue: "No internet connection")
            message = String(localized: "error.offline.message", defaultValue: "Check your connection and try again.")
            allowsRetry = true
        case .timeout:
            title = String(localized: "error.timeout.title", defaultValue: "Request timed out")
            message = String(localized: "error.timeout.message", defaultValue: "The server took too long to respond. Please try again.")
            allowsRetry = true
        case .secureConnectionFailed:
            title = String(localized: "error.secure_connection.title", defaultValue: "Secure connection failed")
            message = String(localized: "error.secure_connection.message", defaultValue: "The server identity could not be verified. Please try again later.")
            allowsRetry = true
        case .unauthorized:
            title = String(localized: "error.unauthorized.title", defaultValue: "Not authorized")
            message = String(localized: "error.unauthorized.message", defaultValue: "You do not have permission to perform this action.")
            allowsRetry = false
        case .sessionExpired:
            title = String(localized: "error.session_expired.title", defaultValue: "Session expired")
            message = String(localized: "error.session_expired.message", defaultValue: "Please sign in again to continue.")
            allowsRetry = false
        case .forbidden:
            title = String(localized: "error.forbidden.title", defaultValue: "Access denied")
            message = String(localized: "error.forbidden.message", defaultValue: "You do not have access to this resource.")
            allowsRetry = false
        case .notFound:
            title = String(localized: "error.not_found.title", defaultValue: "Not found")
            message = String(localized: "error.not_found.message", defaultValue: "The requested data is no longer available.")
            allowsRetry = false
        case .conflict:
            title = String(localized: "error.conflict.title", defaultValue: "Data conflict")
            message = String(localized: "error.conflict.message", defaultValue: "The data has changed. Please refresh and try again.")
            allowsRetry = true
        case .rateLimited:
            title = String(localized: "error.rate_limited.title", defaultValue: "Too many requests")
            message = String(localized: "error.rate_limited.message", defaultValue: "Please wait a moment and try again.")
            allowsRetry = true
        case .foodAnalysisQuotaExceeded:
            title = String(localized: "error.analysis_quota.title", defaultValue: "Analysis limit reached")
            message = String(localized: "error.analysis_quota.message", defaultValue: "Try again later when a new analysis slot is available.")
            allowsRetry = false
        case .serverUnavailable:
            title = String(localized: "error.server_unavailable.title", defaultValue: "Server unavailable")
            message = String(localized: "error.server_unavailable.message", defaultValue: "The service is temporarily unavailable. Please try again later.")
            allowsRetry = true
        case .invalidRequest:
            title = String(localized: "error.invalid_request.title", defaultValue: "Invalid request")
            message = String(localized: "error.invalid_request.message", defaultValue: "Check the entered data and try again.")
            allowsRetry = true
        case .invalidResponse:
            title = String(localized: "error.invalid_response.title", defaultValue: "Unexpected response")
            message = String(localized: "error.invalid_response.message", defaultValue: "The server returned an invalid response. Please try again.")
            allowsRetry = true
        case .decoding:
            title = String(localized: "error.decoding.title", defaultValue: "Data could not be loaded")
            message = String(localized: "error.decoding.message", defaultValue: "The response format was unexpected. Please try again.")
            allowsRetry = true
        case .validation(let message):
            title = String(localized: "error.validation.title", defaultValue: "Check your input")
            self.message = message
            allowsRetry = false
        case .partialSave(let succeeded, let total, let failedNames):
            title = "Saved \(succeeded) of \(total)"
            if failedNames.isEmpty {
                message = "Some items could not be saved."
            } else {
                message = "Not saved: \(failedNames.joined(separator: ", "))."
            }
            allowsRetry = false
        case .permissionDenied:
            title = String(localized: "error.permission_denied.title", defaultValue: "Permission required")
            message = String(localized: "error.permission_denied.message", defaultValue: "Allow access in Settings and try again.")
            allowsRetry = true
        case .storage:
            title = String(localized: "error.storage.title", defaultValue: "Secure storage unavailable")
            message = String(localized: "error.storage.message", defaultValue: "The app could not access secure storage on this device.")
            allowsRetry = false
        case .cancelled:
            title = String(localized: "error.cancelled.title", defaultValue: "Request cancelled")
            message = String(localized: "error.cancelled.message", defaultValue: "The request was cancelled.")
            allowsRetry = false
        case .unknown:
            title = String(localized: "error.unknown.title", defaultValue: "Something went wrong")
            message = String(localized: "error.unknown.message", defaultValue: "An unexpected error occurred. Please try again.")
            allowsRetry = true
        }
    }

}
