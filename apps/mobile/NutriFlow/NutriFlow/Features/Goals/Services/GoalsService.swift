import Foundation

final class GoalsService: GoalsServiceProtocol, Sendable {
    private let client: HTTPClient
    
    init(client: HTTPClient) {
        self.client = client
    }
    
    func getGoals(date: String? = nil) async throws -> UserGoals {
        // Always include the profile time zone. The server uses it both for an
        // explicitly requested calendar day and for its current-day fallback.
        var queryItems = [
            URLQueryItem(name: "tz", value: PreferencesStore.shared.timeZone)
        ]
        if let date {
            queryItems.append(URLQueryItem(name: "date", value: date))
        }
        let request = APIRequest<NeverBody>(
            path: GoalsEndpoints.getGoals,
            method: .GET,
            queryItems: queryItems
        )
        return try await client.send(request)
    }
    
    func updateGoals(calories: Double?, protein: Double?, fat: Double?, carbs: Double?, water: Int?, steps: Int?,activeCalories: Int?,workouts: Int?,workoutMinutes: Int?,sleepMinMinutes: Int?,sleepMaxMinutes: Int?) async throws -> UserGoals {
        let body = UpdateGoalsRequest(
            dailyCaloriesGoal: calories,
            dailyProteinGoal: protein,
            dailyFatGoal: fat,
            dailyCarbsGoal: carbs,
            dailyWaterGoal: water,
            dailyStepsGoal: steps,
            dailyActiveCaloriesGoal: activeCalories,
            weeklyWorkoutsGoal: workouts,
            weeklyWorkoutMinutesGoal: workoutMinutes,
            nightlySleepMinMinutes: sleepMinMinutes,
            nightlySleepMaxMinutes: sleepMaxMinutes
        )
        let request = APIRequest(
            path: GoalsEndpoints.updateGoals,
            method: .PATCH,
            body: body
        )
        return try await client.send(request)
    }
    
    func calculateGoals() async throws -> UserGoals {
        let request = APIRequest<NeverBody>(
            path: GoalsEndpoints.calculateGoals,
            method: .POST
        )
        return try await client.send(request)
    }

    func resetGoalsToAutomatic() async throws -> UserGoals {
        let request = APIRequest<NeverBody>(
            path: GoalsEndpoints.resetToAutomatic,
            method: .POST
        )
        return try await client.send(request)
    }
    
    func getGoalsPreview() async throws -> GoalsPreview {
        let request = APIRequest<NeverBody>(
            path: GoalsEndpoints.preview,
            method: .GET
        )
        return try await client.send(request)
    }

    func applySuggestion(metrics: [GoalMetricKey]?) async throws -> UserGoals {
        let request = APIRequest(
            path: GoalsEndpoints.applySuggestion,
            method: .POST,
            body: ApplySuggestionRequest(metrics: metrics)
        )
        return try await client.send(request)
    }

    func dismissSuggestion() async throws -> UserGoals {
        let request = APIRequest<NeverBody>(
            path: GoalsEndpoints.dismissSuggestion,
            method: .POST
        )
        return try await client.send(request)
    }

    func clearManualOverrides() async throws -> UserGoals {
        let request = APIRequest<NeverBody>(
            path: GoalsEndpoints.clearManualOverrides,
            method: .POST
        )
        return try await client.send(request)
    }

    func clearManualOverride(metric: GoalMetricKey) async throws -> UserGoals {
        let request = APIRequest(
            path: GoalsEndpoints.clearManualOverride,
            method: .POST,
            body: ClearManualOverrideRequest(metric: metric)
        )
        return try await client.send(request)
    }

    func getGoalsProgress(days: Int) async throws -> GoalsProgress {
        let endpoint = GoalsEndpoints.progressRequest(days: days)
        let request = APIRequest<NeverBody>(
            path: endpoint.path,
            method: .GET,
            queryItems: endpoint.query
        )
        return try await client.send(request)
    }

    func applyProgressAdjustment(
        days: Int,
        metrics: GoalMetrics?
    ) async throws -> UserGoals {
        let endpoint = GoalsEndpoints.progressRequest(days: days)
        let request = APIRequest(
            path: GoalsEndpoints.applyProgressAdjustment,
            method: .POST,
            queryItems: endpoint.query,
            body: ProgressApplyRequest(days: nil, metrics: metrics)
        )
        return try await client.send(request)
    }

    func startNewCycle(_ requestBody: NewGoalCycleRequest) async throws -> UserGoals {
        let request = APIRequest(
            path: GoalsEndpoints.newCycle,
            method: .POST,
            body: requestBody
        )
        return try await client.send(request)
    }

    func personalizeGoals() async throws -> PersonalizeResult {
        let request = APIRequest<NeverBody>(
            path: GoalsEndpoints.personalize, method: .POST
        )
        return try await client.send(request)
    }
    
    func getPersonalizationState() async throws -> PersonalizationState {
        let request = APIRequest<NeverBody>(
            path: GoalsEndpoints.personalizationState, method: .GET
        )
        return try await client.send(request)
    }
    
    func acceptRecommendation(id: String) async throws -> GoalMetrics {
        let request = APIRequest<NeverBody>(
            path: GoalsEndpoints.acceptRecommendation(id: id),
            method: .POST
        )
        return try await client.send(request)
    }

    func dismissRecommendation(id: String) async throws -> DismissResult {
        let request = APIRequest<NeverBody>(
            path: GoalsEndpoints.dismissRecommendation(id: id),
            method: .POST
        )
        return try await client.send(request)
    }

    func getGoalHistory(
        date: String?,
        limit: Int?,
        cursor: String?
    ) async throws -> GoalHistoryPage {
        let endpoint = GoalsEndpoints.goalHistory(
            date: date,
            limit: limit,
            cursor: cursor
        )
        let request = APIRequest<NeverBody>(
            path: endpoint.path,
            method: .GET,
            queryItems: endpoint.query
        )
        return try await client.send(request)
    }
}
