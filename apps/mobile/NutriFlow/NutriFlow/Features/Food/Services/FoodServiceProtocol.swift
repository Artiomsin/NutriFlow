import Foundation

protocol FoodServiceProtocol: Sendable {

    // ── Food Entry ──────────────────────────────────────────────

    @discardableResult
    func createFoodEntry(
        name: String,
        calories: Double,
        protein: Double?,
        fat: Double?,
        carbs: Double?,
        foodId: String?,
        grams: Double?,
        unit: String?,
        categoryName: String?,
        imageUrl: String?,
        date: String?
    ) async throws -> FoodEntry

    func getTodayFood() async throws -> [FoodEntry]

    func getFoodByDate(date: String) async throws -> [FoodEntry]

    @discardableResult
    func updateFoodEntry(
        id: String,
        name: String?,
        calories: Double?,
        protein: Double?,
        fat: Double?,
        carbs: Double?,
        grams: Double?,
        unit: String?,
        foodId: String?,
        date: String?,
        imageUrl: String?,
        categoryName: String?
    ) async throws -> FoodEntry

    func deleteFoodEntry(
        id: String,
        date: String?
    ) async throws

    // ── Food Catalog ────────────────────────────────────────────

    func searchFood(query: String, limit: Int, offset: Int) async throws -> FoodSearchResponse

    func getFoods(
        categoryId: String?,
        limit: Int,
        offset: Int
    ) async throws -> [CatalogFoodCategoryGroup]

    func bulkUpdateFoodCategory(
        foodIds: [String],
        categoryId: String?
    ) async throws -> BulkUpdateFoodCategoryResponse
    
    func selectFood(id: String) async throws
    
    func getPopularFood() async throws -> [CatalogFood]

    func getFoodById(_ id: String) async throws -> CatalogFood

    func createCatalogFood(_ request: CreateCatalogFoodRequest) async throws -> CatalogFood

    func getCategories() async throws -> [FoodCategory]

    func createCategory(name: String, icon: String?) async throws -> FoodCategory

    func updateCategory(id: String, name: String?, icon: String?) async throws -> FoodCategory

    func deleteCategory(id: String) async throws

    // ── Upload ──────────────────────────────────────────────────

    func uploadImage(_ data: Data) async throws -> String

    // ── Scan ──────────────────────────────────────────────────

    func analyzePhoto(_ data: Data) async throws -> [ScanAnalysisItem]
}
