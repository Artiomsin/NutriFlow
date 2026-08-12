import Foundation

final class FoodService: FoodServiceProtocol, Sendable {

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    // ── Food Entry ──────────────────────────────────────────────

    func createFoodEntry(
        name: String,
        calories: Int,
        protein: Int?,
        fat: Int?,
        carbs: Int?,
        foodId: String? = nil,
        grams: Int? = nil,
        unit: String? = nil,
        categoryName: String? = nil,
        imageUrl: String? = nil,
        date: String? = nil
    ) async throws -> FoodEntry {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let entryDate = date ?? df.string(from: Date())
        let request = APIRequest(
            path: FoodEndpoints.createFoodEntry,
            method: .POST,
            body: CreateFoodRequest(
                name: name,
                calories: calories,
                protein: protein,
                fat: fat,
                carbs: carbs,
                foodId: foodId,
                grams: grams,
                unit: unit,
                categoryName: categoryName,
                imageUrl: imageUrl,
                date: entryDate
            )
        )
        return try await client.send(request)
    }

    func getTodayFood() async throws -> [FoodEntry] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let date = df.string(from: Date())
        let request = APIRequest<NeverBody>(
            path: "\(FoodEndpoints.getTodayFood)?date=\(date)",
            method: .GET
        )
        return try await client.send(request)
    }

    func getFoodByDate(date: String) async throws -> [FoodEntry] {
        let endpoint = FoodEndpoints.getFoodByDate(date: date)
        let request = APIRequest<NeverBody>(
            path: endpoint.path,
            method: .GET,
            queryItems: endpoint.query
        )
        return try await client.send(request)
    }

    func updateFoodEntry(
        id: String,
        name: String?,
        calories: Int?,
        protein: Int?,
        fat: Int?,
        carbs: Int?,
        grams: Int?,
        foodId: String?,
        date: String?,
        imageUrl: String?,
        categoryName: String?
    ) async throws -> FoodEntry {
        let request = APIRequest(
            path: FoodEndpoints.updateFoodEntry(id: id),
            method: .PATCH,
            body: UpdateFoodEntryRequest(
                name: name,
                calories: calories,
                protein: protein,
                fat: fat,
                carbs: carbs,
                grams: grams,
                foodId: foodId,
                date: date,
                imageUrl: imageUrl,
                categoryName: categoryName
            )
        )
        return try await client.send(request)
    }

    func deleteFoodEntry(id: String, date: String? = nil) async throws {
        let endpoint = FoodEndpoints.deleteFoodEntry(id: id)
        let queryItems: [URLQueryItem] = date.map { [URLQueryItem(name: "date", value: $0)] } ?? []
        let request = APIRequest<NeverBody>(
            path: endpoint,
            method: .DELETE,
            queryItems: queryItems
        )
        try await client.sendVoid(request)
    }

    // ── Food Catalog ────────────────────────────────────────────

    func searchFood(query: String, limit: Int) async throws -> FoodSearchResponse {
        let endpoint = FoodEndpoints.searchFood(query: query, limit: limit)
        let request = APIRequest<NeverBody>(
            path: endpoint.path,
            method: .GET,
            queryItems: endpoint.query
        )
        return try await client.send(request)
    }

    func getPopularFood() async throws -> [CatalogFood] {
        let request = APIRequest<NeverBody>(
            path: FoodEndpoints.getPopularFood,
            method: .GET
        )
        return try await client.send(request)
    }

    func getFoodById(_ id: String) async throws -> CatalogFood {
        let request = APIRequest<NeverBody>(
            path: FoodEndpoints.getFoodById(id),
            method: .GET
        )
        return try await client.send(request)
    }

    func createCatalogFood(_ request: CreateCatalogFoodRequest) async throws -> CatalogFood {
        let apiRequest = APIRequest(
            path: FoodEndpoints.createFood,
            method: .POST,
            body: request
        )
        return try await client.send(apiRequest)
    }

    func getCategories() async throws -> [FoodCategory] {
        let request = APIRequest<NeverBody>(
            path: FoodEndpoints.getCategories,
            method: .GET
        )
        return try await client.send(request)
    }

    // ── Upload ──────────────────────────────────────────────────

    func uploadImage(_ data: Data) async throws -> String {
        try await client.sendUpload(data: data, fileName: "photo.jpg", mimeType: "image/jpeg", path: "/food/upload")
    }
}
