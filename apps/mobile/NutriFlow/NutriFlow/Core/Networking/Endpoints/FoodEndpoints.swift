import Foundation

enum FoodEndpoints {

    static let createFoodEntry = "/food-entry"
    static let getTodayFood = "/food-entry/today"

    static func deleteFoodEntry(id: String) -> String {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        return "/food-entry/\(encoded)"
    }

    static func updateFoodEntry(id: String) -> String {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        return "/food-entry/\(encoded)"
    }

    static func getFoodByDate(date: String) -> (path: String, query: [URLQueryItem]) {
        (path: "/food-entry", query: [URLQueryItem(name: "date", value: date)])
    }


    static let getCategories = "/food-categories"
    static let createCategory = "/food-categories"

    static let getAllFoods = "/foods"
    static let createFood = "/foods"

    static func searchFood(query: String, limit: Int, offset: Int) -> (path: String, query: [URLQueryItem]) {
        (
            path: "/foods/search",
            query: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
        )
    }
    
    static func selectFood(_ id: String) -> String {
        "/foods/\(id)/select"
    }

    static let getPopularFood = "/foods/popular"

    static let analyzeFood = "/food/analyze"

    static func getFoodByBarcode(_ barcode: String) -> String {
        let encoded = barcode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? barcode
        return "/foods/barcode/\(encoded)"
    }

    static func getFoodById(_ id: String) -> String {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        return "/foods/\(encoded)"
    }
}
