import Foundation

extension FoodEntry {
    var displayImageUrl: String? {
        rewriteMinioURL(imageUrl)
    }
}

extension CatalogFood {
    var displayImageUrl: String? {
        rewriteMinioURL(imageUrl)
    }
}

private func rewriteMinioURL(_ url: String?) -> String? {
    guard let url, let apiHost = URL(string: APIConfig.baseURL)?.host else { return url }
    guard var components = URLComponents(string: url) else { return url }
    guard let minioPort = components.port, minioPort == 9000 else { return url }
    components.host = apiHost
    return components.url?.absoluteString ?? url
}

struct CreateFoodRequest: Codable, Sendable {
    let name: String
    let calories: Int
    let protein: Int?
    let fat: Int?
    let carbs: Int?
    let foodId: String?
    let grams: Int?
    let unit: String?
    let categoryName: String?
    let imageUrl: String?
    let date: String?
}

struct UpdateFoodEntryRequest: Codable, Sendable {
    let name: String?
    let calories: Int?
    let protein: Int?
    let fat: Int?
    let carbs: Int?
}

struct FoodEntry: Codable, Identifiable, Sendable {
    let id: String
    let userId: String
    let name: String
    let calories: Int
    let protein: Int?
    let fat: Int?
    let carbs: Int?
    let foodId: String?
    let grams: Int?
    let unit: String
    let categoryName: String?
    let imageUrl: String?
    let createdAt: String
    let updatedAt: String?
}


struct CatalogFood: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let categoryId: String?
    let categoryName: String?
    let brand: String?
    let caloriesPer100g: Int
    let proteinPer100g: Int?
    let fatPer100g: Int?
    let carbsPer100g: Int?
    let barcode: String?
    let imageUrl: String?
    let source: String
    let createdBy: String?
    let createdAt: String
    let updatedAt: String
    let servings: [FoodServing]?
}

struct FoodSearchResponse: Codable, Sendable {
    let foods: [CatalogFood]
    let suggestedGrams: Int?
    let suggestedUnit: String?
}

extension CatalogFood {
    var stableId: String {
        if !id.isEmpty {
            return id
        }
        if let barcode, !barcode.isEmpty {
            return barcode
        }
        return name
    }
}


struct FoodServing: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let foodId: String
    let name: String
    let grams: Int
    let createdAt: String?
}

struct FoodCategory: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let icon: String?
    let createdAt: String
}

struct CategoryWithFoods: Codable, Sendable {
    let category: FoodCategory
    let foods: [CatalogFood]
}

struct CreateCatalogFoodRequest: Codable, Sendable {
    let name: String
    let categoryId: String?
    let caloriesPer100g: Int
    let proteinPer100g: Int?
    let fatPer100g: Int?
    let carbsPer100g: Int?
    let barcode: String?
    let imageUrl: String?
    let servings: [CreateServingRequest]?
}

struct CreateServingRequest: Codable, Sendable {
    let name: String
    let grams: Int
}
