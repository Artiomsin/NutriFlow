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

            errors.set(message(for: problem.code), for: field)
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

    private static var unknownMessage: String {
        String(
            localized: "form.error.unknown",
            defaultValue: "Check this value and try again."
        )
    }
}
