import Foundation

private let guestUserId = "guest"

struct GuestData: Codable, Sendable {
    var foodEntries: [FoodEntry]
    var waterEntries: [WaterEntry]
    var date: String

    static func empty() -> GuestData {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return GuestData(
            foodEntries: [],
            waterEntries: [],
            date: fmt.string(from: Date())
        )
    }
}

extension FoodEntry {
    init(id: String = UUID().uuidString, name: String, calories: Int, protein: Int?, fat: Int?, carbs: Int?, foodId: String? = nil, grams: Int? = nil, unit: String? = nil, categoryName: String? = nil, imageUrl: String? = nil) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        let now = fmt.string(from: Date())
        self.init(id: id, userId: guestUserId, name: name, calories: calories, protein: protein, fat: fat, carbs: carbs, foodId: foodId, grams: grams, unit: unit ?? "g", categoryName: categoryName, imageUrl: imageUrl, createdAt: now, updatedAt: nil)
    }
}

extension WaterEntry {
    init(id: String = UUID().uuidString, amountMl: Int) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        let now = fmt.string(from: Date())
        self.init(id: id, userId: guestUserId, amountMl: amountMl, createdAt: now, updatedAt: nil)
    }
}
