import Foundation

protocol FoodServiceProtocol: Sendable {

    // ── Food Entry ──────────────────────────────────────────────

    @discardableResult
    func createFoodEntry(
        name: String,
        calories: Int,
        protein: Int?,
        fat: Int?,
        carbs: Int?,
        foodId: String?,
        grams: Int?,
        unit: String?,
        categoryName: String?,
        imageUrl: String?,
        date: String?
    ) async throws -> FoodEntry

    func getTodayFood() async throws -> [FoodEntry]

    func getFoodByDate(date: String) async throws -> [FoodEntry]

    func deleteFoodEntry(
        id: String,
        date: String?
    ) async throws

    // ── Food Catalog ────────────────────────────────────────────

    func searchFood(query: String, limit: Int) async throws -> FoodSearchResponse

    func getPopularFood() async throws -> [CatalogFood]

    func getFoodById(_ id: String) async throws -> CatalogFood

    func createCatalogFood(_ request: CreateCatalogFoodRequest) async throws -> CatalogFood

    func getCategories() async throws -> [FoodCategory]

    // ── Upload ──────────────────────────────────────────────────

    func uploadImage(_ data: Data) async throws -> String
}
