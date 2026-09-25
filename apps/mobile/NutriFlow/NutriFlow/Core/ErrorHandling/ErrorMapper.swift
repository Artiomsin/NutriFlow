import Foundation

enum ErrorMapper {
    static func map(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        if let convertible = error as? any AppErrorConvertible {
            return convertible.appError
        }

        if error is CancellationError {
            return .cancelled
        }

        if let urlError = error as? URLError {
            return mapURLErrorCode(urlError.code)
        }

        if error is DecodingError {
            return .decoding
        }

        if error is EncodingError {
            return .invalidRequest
        }

        return .unknown
    }

    private static func mapURLErrorCode(_ code: URLError.Code) -> AppError {
        switch code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .cannotConnectToHost,
             .cannotFindHost,
             .dnsLookupFailed,
             .dataNotAllowed,
             .internationalRoamingOff,
             .cannotLoadFromNetwork:
            return .offline
        case .timedOut:
            return .timeout
        case .cancelled:
            return .cancelled
        case .secureConnectionFailed,
             .serverCertificateHasBadDate,
             .serverCertificateUntrusted,
             .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid,
             .clientCertificateRejected,
             .clientCertificateRequired:
            return .secureConnectionFailed
        case .badURL, .unsupportedURL:
            return .invalidRequest
        case .badServerResponse:
            return .invalidResponse
        case .cannotDecodeRawData, .cannotDecodeContentData:
            return .decoding
        default:
            return .unknown
        }
    }
}