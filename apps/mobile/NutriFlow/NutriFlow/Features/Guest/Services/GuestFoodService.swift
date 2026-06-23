import Foundation

final class GuestFoodService: FoodServiceProtocol {
    private let store: GuestStore

    init(store: GuestStore) {
        self.store = store
    }

    func createFoodEntry(name: String, calories: Int, protein: Int?, fat: Int?, carbs: Int?) async throws -> FoodEntry {
        let entry = FoodEntry(name: name, calories: calories, protein: protein, fat: fat, carbs: carbs)
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

    func deleteFoodEntry(id: String) async throws {
        store.removeFood(id: id)
    }
}
