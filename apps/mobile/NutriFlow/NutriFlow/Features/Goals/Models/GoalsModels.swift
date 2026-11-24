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

    var mode: GoalMode? = nil
    var manualOverrides: [GoalMetricKey: ManualGoalOverride]? = nil
    var fixedMetrics: [GoalMetricKey]? = nil
    var suggestion: GoalSuggestion? = nil
    var hasPendingSuggestion: Bool? = nil
}

enum GoalMode: String, Codable, Sendable, Equatable {
    case auto
    case manual
}

enum GoalMetricKey: String, Codable, CaseIterable, Sendable, Equatable {
    case dailyCaloriesGoal
    case dailyProteinGoal
    case dailyFatGoal
    case dailyCarbsGoal
    case dailyWaterGoal
    case dailyStepsGoal
    case dailyActiveCaloriesGoal
    case weeklyWorkoutsGoal
    case weeklyWorkoutMinutesGoal
    case nightlySleepMinMinutes
    case nightlySleepMaxMinutes
}

struct ManualGoalOverride: Codable, Sendable, Equatable {
    let value: Double
    let setAt: String
}

struct GoalSuggestion: Codable, Sendable, Equatable {
    let goals: GoalMetrics
    let reason: String?
    let suggestedAt: String?
    let diff: [GoalMetricChange]
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

struct GoalMetrics: Codable, Sendable, Equatable {
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
struct GoalMetricChange: Codable, Sendable, Identifiable, Equatable {
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

struct ApplySuggestionRequest: Encodable, Sendable {
    let metrics: [GoalMetricKey]?

    private enum CodingKeys: String, CodingKey {
        case metrics
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(metrics, forKey: .metrics)
    }
}

struct ClearManualOverrideRequest: Encodable, Sendable {
    let metric: GoalMetricKey
}

enum NewGoalCycleAction: String, Codable, Sendable {
    case maintain
    case setNewGoal = "set_new_goal"
    case adjustTempo = "adjust_tempo"
}

struct NewGoalCycleRequest: Encodable, Sendable {
    let action: NewGoalCycleAction
    let goal: Goal?
    let targetWeightKg: Double?
    let targetWeightMinKg: Double?
    let targetWeightMaxKg: Double?
    let weeklyRateKg: Double?
    let targetDate: String?
    let goalStartedAt: String?
}

struct GoalCalculationBasis: Codable, Sendable {
    let currentWeightKg: Double?
    let targetWeightKg: Double?
    let weeklyRateKg: Double?
    let targetDate: String?
    let goal: Goal?
    let activityLevel: ActivityLevel?
}

struct GoalCalculationDetails: Codable, Sendable {
    let bmr: Double?
    let tdee: Double?
    let dailyCalories: Double?
    let rawDailyCalories: Double?
    let dailyDeltaKcal: Double?
    let targetRateKgPerWeek: Double?
    let paceSource: String?
    let minSafeCalories: Double?
    let maxSafeCalories: Double?
    let warnings: [String]?
    let limitedBySafety: Bool?
}

struct GoalEstimatedCompletion: Codable, Sendable {
    let plannedDate: String?
    let byTrendDate: String?
    let remainingKg: Double?
    let targetRateKgPerWeek: Double?
    let actualRateKgPerWeek: Double?
    let isApproximate: Bool?
}

struct GoalsPreview: Codable, Sendable {
    let mode: GoalMode?
    let recommended: GoalMetrics?
    let suggested: GoalMetrics?
    let applied: GoalMetrics?
    let fixedMetrics: [GoalMetricKey]?
    let manualOverrides: [GoalMetricKey: ManualGoalOverride]?
    let diff: [GoalMetricChange]?
    let autoDiff: [GoalMetricChange]?
    let basis: GoalCalculationBasis?
    let calories: GoalCalculationDetails?
    let willApplyAutomatically: Bool?
    let estimatedCompletion: GoalEstimatedCompletion?
}

struct ProgressPeriod: Codable, Sendable {
    let start: String?
    let end: String?
    let days: Int?
    let timeZone: String?
}

struct GoalsProgressMetrics: Codable, Sendable {
    let actualRateKgPerWeek: Double?
    let targetRateKgPerWeek: Double?
    let targetRateSource: String?
    let rateDeltaKgPerWeek: Double?
    let weighInsCount: Int?
    let loggedDaysCount: Int?
    let activityDaysCount: Int?
    let workoutDaysCount: Int?
    let sleepNightsCount: Int?
    let calorieAdherence: Double?
    let proteinAdherence: Double?
    let avgCalories: Double?
    let avgProtein: Double?
    let calorieTarget: Double?
    let proteinTarget: Double?
}

struct GoalProgressAdjustment: Codable, Sendable {
    let metrics: GoalMetrics
    let diff: [GoalMetricChange]
    let note: String?
}

struct GoalsProgressRecommendation: Codable, Sendable {
    let action: String?
    let text: String?
    let nothingToChange: Bool?
    let suggestedAdjustment: GoalProgressAdjustment?
}

struct GoalsProgressGoal: Codable, Sendable {
    let type: Goal?
    let targetWeightKg: Double?
    let weeklyRateKg: Double?
    let targetDate: String?
    let goalStartedAt: String?
    let mode: GoalMode?
}

struct GoalsProgress: Codable, Sendable {
    let period: ProgressPeriod?
    let status: String?
    let reason: String?
    let direction: String?
    let confidence: String?
    let metrics: GoalsProgressMetrics?
    let recommendation: GoalsProgressRecommendation?
    let estimatedCompletion: GoalEstimatedCompletion?
    let appliedGoals: GoalMetrics?
    let goal: GoalsProgressGoal?
}

struct ProgressApplyRequest: Encodable, Sendable {
    let days: Int?
    let metrics: GoalMetrics?

    private enum CodingKeys: String, CodingKey {
        case days
        case metrics
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(days, forKey: .days)
        try container.encodeIfPresent(metrics, forKey: .metrics)
    }
}

enum PersonalizeResult: Decodable, Sendable {
    case created(GoalRecommendation)
    case pendingExists(GoalRecommendation)
    case notDue(lastEvaluationAt: String?, nextAvailableAt: String?)
    case insufficientData
    case collectData
    case noChange

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
        case collectData = "collect_data"
        case noChange = "no_change"
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
        case .collectData:
            self = .collectData
        case .noChange:
            self = .noChange
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
