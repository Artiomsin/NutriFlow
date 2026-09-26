import Foundation

enum WorkoutHealthKitError: Error {

    case queryFailed(underlying: Error)
}

extension WorkoutHealthKitError: AppErrorConvertible {

    var appError: AppError {
        switch self {
        case .queryFailed:
            return .unknown
        }
    }
}
