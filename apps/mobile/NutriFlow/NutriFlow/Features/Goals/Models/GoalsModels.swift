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

    private enum CodingKeys: String, CodingKey {
        case id, userId
        case dailyCaloriesGoal, dailyProteinGoal, dailyFatGoal, dailyCarbsGoal, dailyWaterGoal
        case dailyStepsGoal, dailyActiveCaloriesGoal
        case weeklyWorkoutsGoal, weeklyWorkoutMinutesGoal
        case nightlySleepMinMinutes, nightlySleepMaxMinutes
        case source, createdAt, updatedAt
        case mode, manualOverrides, fixedMetrics, suggestion, hasPendingSuggestion
    }

    init(
        id: String?,
        userId: String?,
        dailyCaloriesGoal: Double?,
        dailyProteinGoal: Double?,
        dailyFatGoal: Double?,
        dailyCarbsGoal: Double?,
        dailyWaterGoal: Int?,
        dailyStepsGoal: Int?,
        dailyActiveCaloriesGoal: Int?,
        weeklyWorkoutsGoal: Int?,
        weeklyWorkoutMinutesGoal: Int?,
        nightlySleepMinMinutes: Int?,
        nightlySleepMaxMinutes: Int?,
        source: String?,
        createdAt: String?,
        updatedAt: String?
    ) {
        self.id = id
        self.userId = userId
        self.dailyCaloriesGoal = dailyCaloriesGoal
        self.dailyProteinGoal = dailyProteinGoal
        self.dailyFatGoal = dailyFatGoal
        self.dailyCarbsGoal = dailyCarbsGoal
        self.dailyWaterGoal = dailyWaterGoal
        self.dailyStepsGoal = dailyStepsGoal
        self.dailyActiveCaloriesGoal = dailyActiveCaloriesGoal
        self.weeklyWorkoutsGoal = weeklyWorkoutsGoal
        self.weeklyWorkoutMinutesGoal = weeklyWorkoutMinutesGoal
        self.nightlySleepMinMinutes = nightlySleepMinMinutes
        self.nightlySleepMaxMinutes = nightlySleepMaxMinutes
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        dailyCaloriesGoal = try container.decodeIfPresent(Double.self, forKey: .dailyCaloriesGoal)
        dailyProteinGoal = try container.decodeIfPresent(Double.self, forKey: .dailyProteinGoal)
        dailyFatGoal = try container.decodeIfPresent(Double.self, forKey: .dailyFatGoal)
        dailyCarbsGoal = try container.decodeIfPresent(Double.self, forKey: .dailyCarbsGoal)
        dailyWaterGoal = try container.decodeIfPresent(Int.self, forKey: .dailyWaterGoal)
        dailyStepsGoal = try container.decodeIfPresent(Int.self, forKey: .dailyStepsGoal)
        dailyActiveCaloriesGoal = try container.decodeIfPresent(Int.self, forKey: .dailyActiveCaloriesGoal)
        weeklyWorkoutsGoal = try container.decodeIfPresent(Int.self, forKey: .weeklyWorkoutsGoal)
        weeklyWorkoutMinutesGoal = try container.decodeIfPresent(Int.self, forKey: .weeklyWorkoutMinutesGoal)
        nightlySleepMinMinutes = try container.decodeIfPresent(Int.self, forKey: .nightlySleepMinMinutes)
        nightlySleepMaxMinutes = try container.decodeIfPresent(Int.self, forKey: .nightlySleepMaxMinutes)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        mode = try container.decodeIfPresent(GoalMode.self, forKey: .mode)
        manualOverrides = try decodeManualOverrides(from: container, forKey: .manualOverrides)
        fixedMetrics = try container.decodeIfPresent([GoalMetricKey].self, forKey: .fixedMetrics)
        suggestion = try container.decodeIfPresent(GoalSuggestion.self, forKey: .suggestion)
        hasPendingSuggestion = try container.decodeIfPresent(Bool.self, forKey: .hasPendingSuggestion)
    }
}

enum GoalMode: String, Codable, Sendable, Equatable {
    case auto
    case manual
}

enum GoalMetricKey: String, Codable, CodingKey, CaseIterable, Sendable, Equatable {
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

struct SuggestedGoalPlan: Codable, Sendable, Equatable {
    let weeklyRateKg: Double?
    let targetDate: String?
    let previousWeeklyRateKg: Double?
    let previousTargetDate: String?
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
    let suggestedPlan: SuggestedGoalPlan?
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

/// Payload for the stateless onboarding preview. Nothing is persisted until
/// the person confirms the plan with `createProfile`.
struct GoalsPreviewDraftRequest: Encodable, Sendable {
    let weight: Double
    let height: Int
    let age: Int
    let gender: Gender
    let goal: Goal
    let activityLevel: ActivityLevel
    let targetWeightKg: Double?
    let targetWeightMinKg: Double?
    let targetWeightMaxKg: Double?
    let weeklyRateKg: Double?
    let targetDate: String?
    let timeZone: String?
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

    private enum CodingKeys: String, CodingKey {
        case mode, recommended, suggested, applied, fixedMetrics, manualOverrides
        case diff, autoDiff, basis, calories, willApplyAutomatically, estimatedCompletion
    }

    init(
        mode: GoalMode?,
        recommended: GoalMetrics?,
        suggested: GoalMetrics?,
        applied: GoalMetrics?,
        fixedMetrics: [GoalMetricKey]?,
        manualOverrides: [GoalMetricKey: ManualGoalOverride]?,
        diff: [GoalMetricChange]?,
        autoDiff: [GoalMetricChange]?,
        basis: GoalCalculationBasis?,
        calories: GoalCalculationDetails?,
        willApplyAutomatically: Bool?,
        estimatedCompletion: GoalEstimatedCompletion?
    ) {
        self.mode = mode
        self.recommended = recommended
        self.suggested = suggested
        self.applied = applied
        self.fixedMetrics = fixedMetrics
        self.manualOverrides = manualOverrides
        self.diff = diff
        self.autoDiff = autoDiff
        self.basis = basis
        self.calories = calories
        self.willApplyAutomatically = willApplyAutomatically
        self.estimatedCompletion = estimatedCompletion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decodeIfPresent(GoalMode.self, forKey: .mode)
        recommended = try container.decodeIfPresent(GoalMetrics.self, forKey: .recommended)
        suggested = try container.decodeIfPresent(GoalMetrics.self, forKey: .suggested)
        applied = try container.decodeIfPresent(GoalMetrics.self, forKey: .applied)
        fixedMetrics = try container.decodeIfPresent([GoalMetricKey].self, forKey: .fixedMetrics)
        manualOverrides = try decodeManualOverrides(from: container, forKey: .manualOverrides)
        diff = try container.decodeIfPresent([GoalMetricChange].self, forKey: .diff)
        autoDiff = try container.decodeIfPresent([GoalMetricChange].self, forKey: .autoDiff)
        basis = try container.decodeIfPresent(GoalCalculationBasis.self, forKey: .basis)
        calories = try container.decodeIfPresent(GoalCalculationDetails.self, forKey: .calories)
        willApplyAutomatically = try container.decodeIfPresent(Bool.self, forKey: .willApplyAutomatically)
        estimatedCompletion = try container.decodeIfPresent(GoalEstimatedCompletion.self, forKey: .estimatedCompletion)
    }
}

private func decodeManualOverrides<Key: CodingKey>(
    from container: KeyedDecodingContainer<Key>,
    forKey key: Key
) throws -> [GoalMetricKey: ManualGoalOverride]? {
    guard let rawOverrides = try container.decodeIfPresent(
        [String: ManualGoalOverride].self,
        forKey: key
    ) else {
        return nil
    }

    return rawOverrides.reduce(into: [:]) { overrides, entry in
        guard let metric = GoalMetricKey(rawValue: entry.key) else { return }
        overrides[metric] = entry.value
    }
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
