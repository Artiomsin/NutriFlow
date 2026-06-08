import Foundation

protocol GoalsServiceProtocol: Sendable {
    func getGoals() async throws -> UserGoals
    func updateGoals(calories: Int?, protein: Int?, fat: Int?, carbs: Int?, water: Int?) async throws -> UserGoals
    func calculateGoals() async throws -> UserGoals
}
