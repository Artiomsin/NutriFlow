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
    case weeklyRateMustBePositive = "WEEKLY_RATE_MUST_BE_POSITIVE"
    case targetDateInPast = "TARGET_DATE_IN_PAST"
    case targetDateMustBeAfterGoalStart = "TARGET_DATE_MUST_BE_AFTER_GOAL_START"
    case targetWeightRequiredForDate = "TARGET_WEIGHT_REQUIRED_FOR_DATE"
    case targetWeightMustBeLowerThanCurrent = "TARGET_WEIGHT_MUST_BE_LOWER_THAN_CURRENT"
    case targetWeightMustBeHigherThanCurrent = "TARGET_WEIGHT_MUST_BE_HIGHER_THAN_CURRENT"
    case maintainRangePairRequired = "MAINTAIN_RANGE_PAIR_REQUIRED"
    case maintainRangeOrderInvalid = "MAINTAIN_RANGE_ORDER_INVALID"
    case maintainRangeWidthOutOfRange = "MAINTAIN_RANGE_WIDTH_OUT_OF_RANGE"
    case maintainRangeTooFarFromCurrent = "MAINTAIN_RANGE_TOO_FAR_FROM_CURRENT"
    case targetWeightOutsideMaintainRange = "TARGET_WEIGHT_OUTSIDE_MAINTAIN_RANGE"
    case targetWeightTooFarFromCurrent = "TARGET_WEIGHT_TOO_FAR_FROM_CURRENT"
    case maintainRangeNotAllowed = "MAINTAIN_RANGE_NOT_ALLOWED"
    case goalRequiredForNewCycle = "GOAL_REQUIRED_FOR_NEW_CYCLE"
    case goalChangeRequiresNewCycle = "GOAL_CHANGE_REQUIRES_NEW_CYCLE"
    case tempoAdjustmentRequired = "TEMPO_ADJUSTMENT_REQUIRED"
}
