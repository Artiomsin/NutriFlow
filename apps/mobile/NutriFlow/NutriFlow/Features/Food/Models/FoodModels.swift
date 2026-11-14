import Foundation

struct CreateFoodRequest: Codable, Sendable {
    let name: String
    let calories: Double
    let protein: Double?
    let fat: Double?
    let carbs: Double?
    let foodId: String?
    let grams: Double?
    let unit: String?
    let barcode: String?
    let categoryName: String?
    let categoryId: String?
    let createPersonalFood: Bool
    let updatePersonalFood: Bool
    let imageUrl: String?
    let date: String?

    enum CodingKeys: String, CodingKey {
        case name, calories, protein, fat, carbs
        case foodId, grams, unit, barcode, imageUrl, date, categoryName, categoryId, createPersonalFood, updatePersonalFood
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(name, forKey: .name)
        try container.encode(calories, forKey: .calories)
        try container.encodeIfPresent(protein, forKey: .protein)
        try container.encodeIfPresent(fat, forKey: .fat)
        try container.encodeIfPresent(carbs, forKey: .carbs)
        try container.encodeIfPresent(grams, forKey: .grams)
        try container.encodeIfPresent(unit, forKey: .unit)
        try container.encodeIfPresent(foodId, forKey: .foodId)
        try container.encodeIfPresent(date, forKey: .date)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encodeIfPresent(barcode, forKey: .barcode)

        // Explicit null means that no category is selected.
        try container.encode(categoryName, forKey: .categoryName)
        try container.encode(categoryId, forKey: .categoryId)
        try container.encode(createPersonalFood, forKey: .createPersonalFood)
        try container.encode(updatePersonalFood, forKey: .updatePersonalFood)
    }
}

struct UpdateFoodEntryRequest: Codable, Sendable {
    let name: String?
    let calories: Double?
    let protein: Double?
    let fat: Double?
    let carbs: Double?
    let grams: Double?
    let unit: String?
    let foodId: String?
    let date: String?
    let imageUrl: String?
    let categoryName: String?

    enum CodingKeys: String, CodingKey {
        case name, calories, protein, fat, carbs
        case grams, unit, foodId, date, imageUrl, categoryName
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(calories, forKey: .calories)
        try container.encodeIfPresent(protein, forKey: .protein)
        try container.encodeIfPresent(fat, forKey: .fat)
        try container.encodeIfPresent(carbs, forKey: .carbs)
        try container.encodeIfPresent(grams, forKey: .grams)
        try container.encodeIfPresent(unit, forKey: .unit)
        try container.encodeIfPresent(foodId, forKey: .foodId)
        try container.encodeIfPresent(date, forKey: .date)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)

        // Explicit null clears the category; omission leaves it unchanged.
        try container.encode(categoryName, forKey: .categoryName)
    }
}

struct FoodEntry: Codable, Identifiable, Sendable {
    let id: String
    let userId: String
    let name: String
    let calories: Double
    let protein: Double?
    let fat: Double?
    let carbs: Double?
    let foodId: String?
    let grams: Double?
    let unit: String
    let categoryName: String?
    let categoryIcon: String?
    var categoryColor: String? = nil
    let imageUrl: String?
    let createdAt: String
    let updatedAt: String?
    var foodSource: String?
}

struct CatalogFood: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let categoryId: String?
    let categoryName: String?
    let brand: String?
    let caloriesPer100g: Double
    let proteinPer100g: Double?
    let fatPer100g: Double?
    let carbsPer100g: Double?
    let barcode: String?
    let imageUrl: String?
    let source: String
    let createdBy: String?
    let createdAt: String
    let updatedAt: String
    let servings: [FoodServing]?
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

    /// Barcode products reuse the editable scan-result screen.
    func analysisItem(grams: Double = 100) -> FoodAnalysisItem {
        let ratio = grams / 100

        return FoodAnalysisItem(
            name: name,
            category: categoryName,
            grams: grams,
            calories: caloriesPer100g * ratio,
            protein: proteinPer100g.map { $0 * ratio },
            fat: fatPer100g.map { $0 * ratio },
            carbs: carbsPer100g.map { $0 * ratio },
            unit: "g",
            imageUrl: imageUrl,
            confidence: nil,
            foodId: id.isEmpty ? nil : id,
            barcode: barcode,
            source: "catalog",
            aiCalories: nil,
            catalogCalories: caloriesPer100g * ratio,
            catalogCaloriesPer100g: caloriesPer100g,
            catalogProteinPer100g: proteinPer100g,
            catalogFatPer100g: fatPer100g,
            catalogCarbsPer100g: carbsPer100g
        )
    }
}

extension CatalogFood {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case categoryId
        case categoryName
        case brand
        case caloriesPer100g
        case proteinPer100g
        case fatPer100g
        case carbsPer100g
        case barcode
        case imageUrl
        case source
        case createdBy
        case createdAt
        case updatedAt
        case servings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Barcode lookup may return an external (Open Food Facts) product that
        // has no local id yet. Treat it as an unsaved product instead of
        // failing to decode the whole response.
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try container.decode(String.self, forKey: .name)
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
        categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        caloriesPer100g = try container.decode(Double.self, forKey: .caloriesPer100g)
        proteinPer100g = try container.decodeIfPresent(Double.self, forKey: .proteinPer100g)
        fatPer100g = try container.decodeIfPresent(Double.self, forKey: .fatPer100g)
        carbsPer100g = try container.decodeIfPresent(Double.self, forKey: .carbsPer100g)
        barcode = try container.decodeIfPresent(String.self, forKey: .barcode)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        source = try container.decode(String.self, forKey: .source)
        createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
        servings = try container.decodeIfPresent([FoodServing].self, forKey: .servings)
    }
}

struct FoodSearchResponse: Codable, Sendable {
    let foods: [CatalogFood]
    let suggestedGrams: Double?
    let suggestedUnit: String?
    let hasMore: Bool
    let total: Int
    let offset: Int
    let limit: Int
}

extension FoodSearchResponse {
    init(
        foods: [CatalogFood],
        suggestedGrams: Double?,
        suggestedUnit: String?
    ) {
        self.foods = foods
        self.suggestedGrams = suggestedGrams
        self.suggestedUnit = suggestedUnit
        self.hasMore = false
        self.total = 0
        self.offset = 0
        self.limit = 20
    }
}

struct FoodServing: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let foodId: String
    let name: String
    let grams: Double
    let createdAt: String?
}

extension FoodServing {
    enum CodingKeys: String, CodingKey {
        case id
        case foodId
        case name
        case grams
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        // Barcode providers return portions without foodId (they are not
        // loaded from the servings table).
        foodId = try container.decodeIfPresent(String.self, forKey: .foodId) ?? ""
        name = try container.decode(String.self, forKey: .name)
        grams = try container.decode(Double.self, forKey: .grams)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

struct FoodCategory: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let icon: String?
    let color: String?
    let createdBy: String?
    let createdAt: String
    let foodCount: Int

    var isPersonal: Bool {
        createdBy != nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case icon
        case color
        case createdBy
        case createdAt
        case foodCount
    }

    init(
        id: String,
        name: String,
        icon: String?,
        color: String?,
        createdBy: String?,
        createdAt: String,
        foodCount: Int
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.foodCount = foodCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        foodCount = try container.decodeIfPresent(Int.self, forKey: .foodCount) ?? 0
    }
}

struct CreateFoodCategoryRequest: Codable, Sendable {
    let name: String
    let icon: String?
    let color: String?
}

struct UpdateFoodCategoryRequest: Codable, Sendable {
    let name: String?
    let icon: String?
    let color: String?
}

struct CategoryWithFoods: Codable, Sendable {
    let category: FoodCategory
    let foods: [CatalogFood]
}

struct CatalogFoodCategoryGroup: Codable, Sendable {
    let id: String
    let name: String
    let icon: String?
    let foods: [CatalogFood]
}

struct BulkUpdateFoodCategoryRequest: Codable, Sendable {
    let foodIds: [String]
    let categoryId: String?

    private enum CodingKeys: String, CodingKey {
        case foodIds
        case categoryId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(foodIds, forKey: .foodIds)

        if let categoryId {
            try container.encode(categoryId, forKey: .categoryId)
        } else {
            try container.encodeNil(forKey: .categoryId)
        }
    }
}

struct BulkUpdateFoodCategoryResponse: Codable, Sendable {
    let updatedCount: Int
    let foodIds: [String]
    let categoryId: String?
}

struct CreateCatalogFoodRequest: Codable, Sendable {
    let name: String
    let categoryId: String?
    let caloriesPer100g: Double
    let proteinPer100g: Double?
    let fatPer100g: Double?
    let carbsPer100g: Double?
    let barcode: String?
    let imageUrl: String?
    let servings: [CreateServingRequest]?
}

struct CreateServingRequest: Codable, Sendable {
    let name: String
    let grams: Double
}

enum ScanAnalysisItem: Decodable, Hashable, Sendable {
    case food(FoodAnalysisItem)
    case water(WaterAnalysisItem)

    private enum CodingKeys: String, CodingKey {
        case kind
    }

    private enum Kind: String, Decodable {
        case food
        case water
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Backward compatibility with responses without the discriminator.
        switch try container.decodeIfPresent(Kind.self, forKey: .kind) {
        case .water:
            self = .water(try WaterAnalysisItem(from: decoder))
        case .food, .none:
            self = .food(try FoodAnalysisItem(from: decoder))
        }
    }
}

struct WaterAnalysisItem: Codable, Hashable, Sendable {
    let amountMl: Int
    let containers: Int?
    let confidence: Double?
}

struct FoodAnalysisItem: Codable, Identifiable, Hashable, Sendable {
    let name: String?
    let category: String?
    let grams: Double?
    let calories: Double?
    let protein: Double?
    let fat: Double?
    let carbs: Double?
    let unit: String?
    let imageUrl: String?
    let confidence: Double?
    let foodId: String?
    let barcode: String?
    let source: String?
    let aiCalories: Double?
    let catalogCalories: Double?
    let catalogCaloriesPer100g: Double?
    let catalogProteinPer100g: Double?
    let catalogFatPer100g: Double?
    let catalogCarbsPer100g: Double?

    var id: String {
        name ?? UUID().uuidString
    }

    var displayName: String {
        name ?? "Unknown food"
    }

    var bestCalories: Double? {
        if source == "catalog" {
            return catalogCalories ?? calories
        }

        return aiCalories ?? calories
    }
}
