import Foundation

protocol GoalsServiceProtocol: Sendable {
    func getGoals(date: String?) async throws -> UserGoals
    func updateGoals(calories: Double?, protein: Double?, fat: Double?, carbs: Double?, water: Int?, steps: Int?,activeCalories: Int?,workouts: Int?,workoutMinutes: Int?,sleepMinMinutes: Int?,sleepMaxMinutes: Int?) async throws -> UserGoals
    func calculateGoals() async throws -> UserGoals
    func resetGoalsToAutomatic() async throws -> UserGoals
    func getGoalsPreview() async throws -> GoalsPreview
    func previewDraft(_ request: GoalsPreviewDraftRequest) async throws -> GoalsPreview
    func applySuggestion(metrics: [GoalMetricKey]?) async throws -> UserGoals
    func dismissSuggestion() async throws -> UserGoals
    func clearManualOverrides() async throws -> UserGoals
    func clearManualOverride(metric: GoalMetricKey) async throws -> UserGoals
    func getGoalsProgress(days: Int) async throws -> GoalsProgress
    func applyProgressAdjustment(days: Int, metrics: GoalMetrics?) async throws -> UserGoals
    func startNewCycle(_ request: NewGoalCycleRequest) async throws -> UserGoals
    func personalizeGoals() async throws -> PersonalizeResult
    func getPersonalizationState() async throws -> PersonalizationState
    func acceptRecommendation(id: String) async throws -> UserGoals
    func dismissRecommendation(id: String) async throws -> DismissResult
    func getGoalHistory(
        date: String?,
        limit: Int?,
        cursor: String?
    ) async throws -> GoalHistoryPage
}

extension GoalsServiceProtocol {
    /// Goals that are active right now (no historical date filter).
    func getGoals() async throws -> UserGoals {
        try await getGoals(date: nil)
    }

    func getGoalHistory(
        limit: Int = 20,
        cursor: String? = nil
    ) async throws -> GoalHistoryPage {
        try await getGoalHistory(date: nil, limit: limit, cursor: cursor)
    }

    func getGoalHistory(date: String) async throws -> GoalHistoryPage {
        try await getGoalHistory(date: date, limit: nil, cursor: nil)
    }
}
