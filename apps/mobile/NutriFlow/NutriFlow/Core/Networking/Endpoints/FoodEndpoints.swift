import Foundation

enum FoodEndpoints {

    static let uploadFoodImage = "/food/upload"
    static let analyzeFood = "/food/analyze"

    static let createFoodEntry = "/food-entry"

    static func getTodayFood(date: String?) -> (path: String, query: [URLQueryItem]) {
        (path: "/food-entry/today", query: date.map { [URLQueryItem(name: "date", value: $0)] } ?? [])
    }

    static func deleteFoodEntry(id: String, date: String?) -> (path: String, query: [URLQueryItem]) {
        let encoded = EndpointPath.component(id)
        return (path: "/food-entry/\(encoded)", query: date.map { [URLQueryItem(name: "date", value: $0)] } ?? [])
    }

    static func updateFoodEntry(id: String) -> String {
        "/food-entry/\(EndpointPath.component(id))"
    }

    static func getFoodByDate(date: String) -> (path: String, query: [URLQueryItem]) {
        (path: "/food-entry", query: [URLQueryItem(name: "date", value: date)])
    }


    static let getCategories = "/food-categories"
    static let createCategory = "/food-categories"

    static func updateFoodCategory(id: String) -> String {
        "/food-categories/\(EndpointPath.component(id))"
    }

    static func deleteFoodCategory(id: String) -> String {
        "/food-categories/\(EndpointPath.component(id))"
    }

    static let getAllFoods = "/foods"
    static let createFood = "/foods"
    static let bulkUpdateFoodCategory = "/foods/bulk/category"

    static func getFoods(
        categoryId: String?,
        limit: Int,
        offset: Int
    ) -> (path: String, query: [URLQueryItem]) {
        var query = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        if let categoryId {
            query.append(URLQueryItem(name: "categoryId", value: categoryId))
        }

        return (path: getAllFoods, query: query)
    }

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
        "/foods/\(EndpointPath.component(id))/select"
    }

    static let getPopularFood = "/foods/popular"

    static func getFoodByBarcode(_ barcode: String) -> String {
        "/foods/barcode/\(EndpointPath.component(barcode))"
    }

    static func getFoodById(_ id: String) -> String {
        "/foods/\(EndpointPath.component(id))"
    }

    static func createServing(foodID: String) -> String {
        "/foods/\(EndpointPath.component(foodID))/servings"
    }

    static func updateServing(foodID: String, servingID: String) -> String {
        "/foods/\(EndpointPath.component(foodID))/servings/\(EndpointPath.component(servingID))"
    }

    static func deleteServing(foodID: String, servingID: String) -> String {
        "/foods/\(EndpointPath.component(foodID))/servings/\(EndpointPath.component(servingID))"
    }
}
