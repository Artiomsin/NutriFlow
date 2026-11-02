
import Foundation

enum ErrorHandlingResult: Equatable, Sendable {
    case fieldErrors(FormFieldErrors)
    case general(AppError)
}

enum ErrorHandler {

    static func handle(
        _ error: Error,
        supportedFields: Set<String> = []
    ) -> ErrorHandlingResult {

        let problems = (error as? any AppErrorConvertible)?.fieldErrors ?? []

        guard !problems.isEmpty else {
            return .general(ErrorMapper.map(error))
        }

        guard !supportedFields.isEmpty else {
            return .general(ErrorMapper.map(error))
        }

        let supportedCodes = Set(
            FieldErrorCode.allCases
                .filter { $0 != .unknownField }
                .map(\.rawValue)
        )

        let allProblemsSupported = problems.allSatisfy { problem in
            let field = problem.field
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let code = problem.code
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()

            return !field.isEmpty
                && supportedFields.contains(field)
                && supportedCodes.contains(code)
        }

        guard allProblemsSupported else {
            return .general(ErrorMapper.map(error))
        }

        return .fieldErrors(
            FormErrorMapper.fieldErrors(from: problems)
        )
    }
}

