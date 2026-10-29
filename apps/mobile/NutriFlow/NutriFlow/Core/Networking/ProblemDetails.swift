import Foundation

enum ProblemType: String, Sendable {
    case invalidRequest = "https://api.nutriflow.app/problems/invalid-request"
    case validationFailed = "https://api.nutriflow.app/problems/validation-failed"
    case unauthorized = "https://api.nutriflow.app/problems/unauthorized"
    case forbidden = "https://api.nutriflow.app/problems/forbidden"
    case notFound = "https://api.nutriflow.app/problems/not-found"
    case conflict = "https://api.nutriflow.app/problems/conflict"
    case requestTimeout = "https://api.nutriflow.app/problems/request-timeout"
    case rateLimited = "https://api.nutriflow.app/problems/rate-limited"
    case foodAnalysisQuotaExceeded = "https://api.nutriflow.app/problems/food-analysis-quota-exceeded"
    case serverError = "https://api.nutriflow.app/problems/server-error"
}

struct FieldProblem: Decodable, Equatable, Sendable {
    let field: String
    let code: String
}

struct ProblemDetails: Decodable, Equatable, Sendable {
    let type: String
    let title: String
    let status: Int
    let detail: String?
    let instance: String?
    let fieldErrors: [FieldProblem]

    private enum CodingKeys: String, CodingKey {
        case type
        case title
        case status
        case detail
        case instance
        case fieldErrors
    }

    var problemType: ProblemType? {
        ProblemType(rawValue: type)
    }

    var requestId: String? {
        guard let instance else { return nil }
        return instance.replacingOccurrences(of: "urn:uuid:", with: "")
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        status = try container.decode(Int.self, forKey: .status)
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
        instance = try container.decodeIfPresent(String.self, forKey: .instance)
        fieldErrors = try container.decodeIfPresent(
            [FieldProblem].self,
            forKey: .fieldErrors
        ) ?? []
    }
}
