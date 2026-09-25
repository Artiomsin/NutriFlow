import Foundation

struct ErrorPresentation: Equatable {
    let title: String
    let message: String
    let allowsRetry: Bool

    init(error: AppError) {
        switch error {
        case .offline:
            title = "No internet connection"
            message = "Check your connection and try again."
            allowsRetry = true
        case .timeout:
            title = "Request timed out"
            message = "The server took too long to respond. Please try again."
            allowsRetry = true
        case .secureConnectionFailed:
            title = "Secure connection failed"
            message = "The server identity could not be verified. Please try again later."
            allowsRetry = true
        case .unauthorized:
            title = "Not authorized"
            message = "You do not have permission to perform this action."
            allowsRetry = false
        case .sessionExpired:
            title = "Session expired"
            message = "Please sign in again to continue."
            allowsRetry = false
        case .forbidden:
            title = "Access denied"
            message = "You do not have access to this resource."
            allowsRetry = false
        case .notFound:
            title = "Not found"
            message = "The requested data is no longer available."
            allowsRetry = false
        case .conflict:
            title = "Data conflict"
            message = "The data has changed. Please refresh and try again."
            allowsRetry = true
        case .rateLimited:
            title = "Too many requests"
            message = "Please wait a moment and try again."
            allowsRetry = true
        case .serverUnavailable:
            title = "Server unavailable"
            message = "The service is temporarily unavailable. Please try again later."
            allowsRetry = true
        case .invalidRequest:
            title = "Invalid request"
            message = "Check the entered data and try again."
            allowsRetry = true
        case .invalidResponse:
            title = "Unexpected response"
            message = "The server returned an invalid response. Please try again."
            allowsRetry = true
        case .decoding:
            title = "Data could not be loaded"
            message = "The response format was unexpected. Please try again."
            allowsRetry = true
        case .validation(let message):
            title = "Check your input"
            self.message = message
            allowsRetry = false
        case .permissionDenied:
            title = "Permission required"
            message = "Allow access in Settings and try again."
            allowsRetry = true
        case .storage:
            title = "Secure storage unavailable"
            message = "The app could not access secure storage on this device."
            allowsRetry = false
        case .cancelled:
            title = "Request cancelled"
            message = "The request was cancelled."
            allowsRetry = false
        case .unknown:
            title = "Something went wrong"
            message = "An unexpected error occurred. Please try again."
            allowsRetry = true
        }
    }
}
