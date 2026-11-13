import Foundation

/// Stable validation codes shared with the API contract.
///
/// The backend never sends user-facing text for field errors. It sends one of
/// these codes, and the app owns the localized copy.
enum FieldErrorCode: String, CaseIterable, Sendable {
    case required = "REQUIRED"
    case invalidEmail = "INVALID_EMAIL"
    case invalidFormat = "INVALID_FORMAT"
    case invalidType = "INVALID_TYPE"
    case invalidValue = "INVALID_VALUE"
    case alreadyExists = "ALREADY_EXISTS"
    case tooShort = "TOO_SHORT"
    case tooLong = "TOO_LONG"
    case outOfRange = "OUT_OF_RANGE"
    case unknownField = "UNKNOWN_FIELD"
}
