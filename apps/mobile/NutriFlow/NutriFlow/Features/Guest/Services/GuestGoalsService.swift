import Foundation

final class GuestGoalsService: GoalsServiceProtocol {
    private let defaultGoals = UserGoals(
        id: nil,
        userId: nil,
        dailyCaloriesGoal: 2200,
        dailyProteinGoal: 150,
        dailyFatGoal: 65,
        dailyCarbsGoal: 250,
        dailyWaterGoal: 3000,
        source: "default",
        createdAt: nil,
        updatedAt: nil
    )

    func getGoals() async throws -> UserGoals {
        defaultGoals
    }

    func updateGoals(calories: Int?, protein: Int?, fat: Int?, carbs: Int?, water: Int?) async throws -> UserGoals {
        UserGoals(
            id: nil,
            userId: nil,
            dailyCaloriesGoal: calories ?? defaultGoals.dailyCaloriesGoal,
            dailyProteinGoal: protein ?? defaultGoals.dailyProteinGoal,
            dailyFatGoal: fat ?? defaultGoals.dailyFatGoal,
            dailyCarbsGoal: carbs ?? defaultGoals.dailyCarbsGoal,
            dailyWaterGoal: water ?? defaultGoals.dailyWaterGoal,
            source: "manual",
            createdAt: nil,
            updatedAt: nil
        )
    }

    func calculateGoals() async throws -> UserGoals {
        defaultGoals
    }
}
