import Foundation

final class FoodService: FoodServiceProtocol, Sendable {

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func createFoodEntry(name: String, calories: Int, protein: Int?, fat: Int?, carbs: Int?) async throws -> FoodEntry {
        let request = APIRequest(
            path: FoodEndpoints.createFoodEntry,
            method: .POST,
            body: CreateFoodRequest(name: name, calories: calories, protein: protein, fat: fat, carbs: carbs)
        )
        return try await client.send(request)
    }

    func getTodayFood() async throws -> [FoodEntry] {
        let request = APIRequest<NeverBody>(
            path: FoodEndpoints.getTodayFood,
            method: .GET
        )
        return try await client.send(request)
    }

    func deleteFoodEntry(id: String) async throws {
        let request = APIRequest<NeverBody>(
            path: FoodEndpoints.deleteFoodEntry(id: id),
            method: .DELETE
        )
        try await client.sendVoid(request)
    }
}
