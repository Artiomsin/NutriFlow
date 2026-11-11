import Foundation

struct UserGoals: Codable, Sendable, Equatable {
    let id: String?
    let userId: String?
    let dailyCaloriesGoal: Double?
    let dailyProteinGoal: Double?
    let dailyFatGoal: Double?
    let dailyCarbsGoal: Double?
    let dailyWaterGoal: Int?
    
    let dailyStepsGoal: Int?
    let dailyActiveCaloriesGoal: Int?
    
    let weeklyWorkoutsGoal: Int?
    let weeklyWorkoutMinutesGoal: Int?
    
    let nightlySleepMinMinutes: Int?
    let nightlySleepMaxMinutes: Int?
    
    let source: String?
    let createdAt: String?
    let updatedAt: String?
}

struct UpdateGoalsRequest: Codable, Sendable {
    let dailyCaloriesGoal: Double?
    let dailyProteinGoal: Double?
    let dailyFatGoal: Double?
    let dailyCarbsGoal: Double?
    let dailyWaterGoal: Int?
    let dailyStepsGoal: Int?
    let dailyActiveCaloriesGoal: Int?
    let weeklyWorkoutsGoal: Int?
    let weeklyWorkoutMinutesGoal: Int?
    let nightlySleepMinMinutes: Int?
    let nightlySleepMaxMinutes: Int?
}

struct GoalMetrics: Codable, Sendable {
    let dailyCaloriesGoal: Double?
    let dailyProteinGoal: Double?
    let dailyFatGoal: Double?
    let dailyCarbsGoal: Double?
    let dailyWaterGoal: Int?

    let dailyStepsGoal: Int?
    let dailyActiveCaloriesGoal: Int?

    let weeklyWorkoutsGoal: Int?
    let weeklyWorkoutMinutesGoal: Int?

    let nightlySleepMinMinutes: Int?
    let nightlySleepMaxMinutes: Int?
}

struct RecommendationConfidence: Codable, Sendable {
    let level: String
    let dataQualityScore: Double
    let trackedDays: Int
    let weightLogsCount: Int
    let activityDays: Int
    let workoutCount: Int
    let sleepNights: Int
    let adherenceStepsPct: Double?
    let weightTrendKgPerWeek: Double?
}

struct GoalRecommendation: Codable, Sendable {
    let id: String
    let userId: String?
    let status: String
    let previousGoals: GoalMetrics
    let recommendedGoals: GoalMetrics
    let analysisPeriodStart: String
    let analysisPeriodEnd: String
    let reasons: [String]
    let confidence: RecommendationConfidence
    let createdAt: String
    let expiresAt: String
    let acceptedAt: String?
    let dismissedAt: String?
}

struct PersonalizationState: Codable, Sendable {
    let pending: GoalRecommendation?
    let personalizationDue: Bool
    let nextAvailableAt: String?
}

struct DismissResult: Codable, Sendable {
    let dismissed: Bool
}

/// One goal field that changed when a new goal version was created.
struct GoalMetricChange: Codable, Sendable, Identifiable {
    let metric: String
    let from: Double?
    let to: Double?

    var id: String { metric }
}

/// A stored goal version. One entry is one change event, not one field.
struct GoalVersionEntry: Codable, Sendable, Identifiable {
    let id: String
    let startedAt: String
    let endedAt: String?
    let source: String
    let reason: String?
    let changes: [GoalMetricChange]
    let goal: GoalMetrics
}

struct GoalHistoryPage: Codable, Sendable {
    let items: [GoalVersionEntry]
    let nextCursor: String?
}

enum PersonalizeResult: Decodable, Sendable {
    case created(GoalRecommendation)
    case pendingExists(GoalRecommendation)
    case notDue(lastEvaluationAt: String?, nextAvailableAt: String?)
    case insufficientData

    private enum CodingKeys: String, CodingKey {
        case status
        case recommendation
        case lastEvaluationAt
        case nextAvailableAt
    }

    private enum StatusValue: String, Decodable {
        case created
        case pendingExists = "pending_exists"
        case notDue = "not_due"
        case insufficientData = "insufficient_data"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(StatusValue.self, forKey: .status) {
        case .created:
            self = .created(
                try container.decode(GoalRecommendation.self, forKey: .recommendation)
            )
        case .pendingExists:
            self = .pendingExists(
                try container.decode(GoalRecommendation.self, forKey: .recommendation)
            )
        case .notDue:
            self = .notDue(
                lastEvaluationAt: try? container.decode(String.self, forKey: .lastEvaluationAt),
                nextAvailableAt: try? container.decode(String.self, forKey: .nextAvailableAt)
            )
        case .insufficientData:
            self = .insufficientData
        }
    }
}

extension UserGoals {
    func applying(_ metrics: GoalMetrics, source: String? = nil) -> UserGoals {
        UserGoals(
            id: id,
            userId: userId,
            dailyCaloriesGoal: metrics.dailyCaloriesGoal ?? dailyCaloriesGoal,
            dailyProteinGoal: metrics.dailyProteinGoal ?? dailyProteinGoal,
            dailyFatGoal: metrics.dailyFatGoal ?? dailyFatGoal,
            dailyCarbsGoal: metrics.dailyCarbsGoal ?? dailyCarbsGoal,
            dailyWaterGoal: metrics.dailyWaterGoal ?? dailyWaterGoal,
            dailyStepsGoal: metrics.dailyStepsGoal ?? dailyStepsGoal,
            dailyActiveCaloriesGoal: metrics.dailyActiveCaloriesGoal ?? dailyActiveCaloriesGoal,
            weeklyWorkoutsGoal: metrics.weeklyWorkoutsGoal ?? weeklyWorkoutsGoal,
            weeklyWorkoutMinutesGoal: metrics.weeklyWorkoutMinutesGoal ?? weeklyWorkoutMinutesGoal,
            nightlySleepMinMinutes: metrics.nightlySleepMinMinutes ?? nightlySleepMinMinutes,
            nightlySleepMaxMinutes: metrics.nightlySleepMaxMinutes ?? nightlySleepMaxMinutes,
            source: source ?? self.source,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
