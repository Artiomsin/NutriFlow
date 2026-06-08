import Foundation

protocol FoodServiceProtocol: Sendable {

    @discardableResult
    func createFoodEntry(
        name: String,
        calories: Int,
        protein: Int?,
        fat: Int?,
        carbs: Int?
    ) async throws -> FoodEntry

    func getTodayFood() async throws -> [FoodEntry]

    func deleteFoodEntry(
        id: String
    ) async throws
}
