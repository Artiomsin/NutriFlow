import Foundation

protocol FoodServiceProtocol {

    func createFoodEntry(
        token: String,
        name: String,
        calories: Int,
        protein: Int?,
        fat: Int?,
        carbs: Int?
    ) async throws -> FoodEntry

    func getTodayFood(
        token: String
    ) async throws -> [FoodEntry]

    func deleteFoodEntry(
        token: String,
        id: String
    ) async throws -> EmptyResponse
}
