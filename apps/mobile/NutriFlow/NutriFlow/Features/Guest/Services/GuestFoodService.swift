import Foundation

final class GuestFoodService: FoodServiceProtocol {
    private let store: GuestStore

    init(store: GuestStore) {
        self.store = store
    }

    func createFoodEntry(name: String, calories: Int, protein: Int?, fat: Int?, carbs: Int?, foodId: String? = nil, grams: Int? = nil, unit: String? = nil, categoryName: String? = nil, imageUrl: String? = nil, date: String? = nil) async throws -> FoodEntry {
        let entry = FoodEntry(name: name, calories: calories, protein: protein, fat: fat, carbs: carbs, foodId: foodId, grams: grams, unit: unit ?? "g", categoryName: categoryName, imageUrl: imageUrl)
        store.addFood(entry)
        return entry
    }

    func getTodayFood() async throws -> [FoodEntry] {
        store.todayFood
    }

    func getFoodByDate(date: String) async throws -> [FoodEntry] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())
        return date == today ? store.todayFood : []
    }

    func deleteFoodEntry(id: String, date: String? = nil) async throws {
        store.removeFood(id: id)
    }

    func searchFood(query: String, limit: Int) async throws -> FoodSearchResponse {
        FoodSearchResponse(foods: [], suggestedGrams: nil, suggestedUnit: nil)
    }

    func getPopularFood() async throws -> [CatalogFood] { [] }

    func getFoodById(_ id: String) async throws -> CatalogFood {
        throw NSError(domain: "GuestFoodService", code: -1)
    }

    func createCatalogFood(_ request: CreateCatalogFoodRequest) async throws -> CatalogFood {
        throw NSError(domain: "GuestFoodService", code: -1)
    }

    func getCategories() async throws -> [FoodCategory] { [] }

    func uploadImage(_ data: Data) async throws -> String {
        throw NSError(domain: "GuestFoodService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Upload not supported in guest mode"])
    }
}
