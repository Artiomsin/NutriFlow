import Foundation

final class GoalsService: GoalsServiceProtocol, Sendable {
    private let client: HTTPClient
    
    init(client: HTTPClient) {
        self.client = client
    }
    
    func getGoals() async throws -> UserGoals {
        let request = APIRequest<NeverBody>(
            path: GoalsEndpoints.getGoals,
            method: .GET
        )
        return try await client.send(request)
    }
    
    func updateGoals(calories: Int?, protein: Int?, fat: Int?, carbs: Int?, water: Int?, steps: Int?,activeCalories: Int?,workouts: Int?,workoutMinutes: Int?,sleepMinMinutes: Int?,sleepMaxMinutes: Int?) async throws -> UserGoals {
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

    func getGoalHistory() async throws -> [GoalHistoryEntry] {
        let request = APIRequest<NeverBody>(
            path: GoalsEndpoints.goalHistory,
            method: .GET
        )
        return try await client.send(request)
    }
}
