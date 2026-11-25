import Foundation

/// Turns stable API validation codes into localized form copy.
///
/// Keep this mapping small and total: an unknown code must still produce a
/// usable message instead of leaking the raw code into the UI.
enum FormErrorMapper {
    static func fieldErrors(from problems: [FieldProblem]) -> FormFieldErrors {
        var errors = FormFieldErrors()

        for problem in problems {
            let field = problem.field
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !field.isEmpty else { continue }

            errors.set(message(for: FieldProblem(field: field, code: problem.code)), for: field)
        }

        return errors
    }

    static func message(for code: String) -> String {
        let normalized = code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard let code = FieldErrorCode(rawValue: normalized) else {
            return unknownMessage
        }

        switch code {
        case .required:
            return String(
                localized: "form.error.required",
                defaultValue: "This field is required."
            )
        case .invalidEmail:
            return String(
                localized: "form.error.invalid_email",
                defaultValue: "Enter a valid email address."
            )
        case .invalidFormat, .invalidType:
            return String(
                localized: "form.error.invalid_format",
                defaultValue: "Enter a valid value."
            )
        case .invalidValue:
            return String(
                localized: "form.error.invalid_value",
                defaultValue: "Choose a valid option."
            )
        case .alreadyExists:
            return String(
                localized: "form.error.already_exists",
                defaultValue: "This name is already taken."
            )
        case .tooShort:
            return String(
                localized: "form.error.too_short",
                defaultValue: "This value is too short."
            )
        case .tooLong:
            return String(
                localized: "form.error.too_long",
                defaultValue: "This value is too long."
            )
        case .outOfRange:
            return String(
                localized: "form.error.out_of_range",
                defaultValue: "Enter a value within the allowed range."
            )
        case .unknownField:
            return String(
                localized: "form.error.unknown_field",
                defaultValue: "This field is not recognized."
            )
        }
    }

    /// Adds the missing context that the current API contract does not carry in
    /// `FieldProblem` (it contains only a field name and stable error code).
    /// Keep required errors generic: they already explain the action clearly.
    static func message(for problem: FieldProblem) -> String {
        let code = problem.code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code != FieldErrorCode.required.rawValue else {
            return message(for: problem.code)
        }

        switch problem.field.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "weight":
            return "Enter a weight between \(displayWeight(20)) and \(displayWeight(400))."
        case "height":
            return "Enter a height between 80 and 250 cm."
        case "age":
            return "Enter an age between 13 and 120."
        case "targetWeightKg":
            return "Enter a target between \(displayWeight(20)) and \(displayWeight(400)) that matches your selected direction."
        case "targetWeightMinKg", "targetWeightMaxKg":
            return "Enter both limits between \(displayWeight(20)) and \(displayWeight(400)). The range must be 0.5–10 kg wide."
        case "weeklyRateKg":
            return "Enter a pace between 0.1 and 2 kg per week."
        case "targetDate":
            return "Choose a date at least 14 days from today."
        default:
            return message(for: problem.code)
        }
    }

    private static func displayWeight(_ kilograms: Double) -> String {
        let units = PreferencesStore.shared.preferredUnits
        let value = UnitConversion.formatBodyWeight(kg: kilograms, preferred: units)
        let unit = UnitConversion.bodyWeightUnitLabel(preferred: units)
        return "\(value) \(unit)"
    }

    private static var unknownMessage: String {
        String(
            localized: "form.error.unknown",
            defaultValue: "Check this value and try again."
        )
    }
}
