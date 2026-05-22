import Foundation

enum FoodEndpoints {

    static let createFoodEntry = "/food-entry"
    static let getTodayFood = "/food-entry/today"
    static func deleteFoodEntry(id: String) -> String {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        return "/food-entry/\(encoded)"
    }
}
