import Foundation

final class MockFoodService: FoodServiceProtocol {
    func createFoodEntry(name: String, calories: Double, protein: Double?, fat: Double?, carbs: Double?, foodId: String? = nil, grams: Double? = nil, unit: String? = nil, categoryName: String? = nil, categoryId: String? = nil, createPersonalFood: Bool = false, updatePersonalFood: Bool = false, imageUrl: String? = nil, date: String? = nil) async throws -> FoodEntry {
        FoodEntry(id: UUID().uuidString, userId: "1", name: name, calories: calories, protein: protein, fat: fat, carbs: carbs, foodId: foodId, grams: grams, unit: unit ?? "g", categoryName: categoryName, categoryIcon: nil,imageUrl: imageUrl, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil)
    }
    func getTodayFood() async throws -> [FoodEntry] {
        [
            FoodEntry(id: "1", userId: "1", name: "Oatmeal", calories: 320, protein: 12, fat: 6, carbs: 56, foodId: nil, grams: nil, unit: "g", categoryName: nil, categoryIcon: nil,imageUrl: nil, createdAt: "2026-05-18T08:00:00Z", updatedAt: nil),
            FoodEntry(id: "2", userId: "1", name: "Chicken breast", calories: 165, protein: 31, fat: 4, carbs: 0, foodId: nil, grams: nil, unit: "g", categoryName: nil,categoryIcon: nil, imageUrl: nil, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil),
            FoodEntry(id: "3", userId: "1", name: "Rice", calories: 200, protein: 4, fat: 1, carbs: 45, foodId: nil, grams: nil, unit: "g", categoryName: nil, categoryIcon: nil,imageUrl: nil, createdAt: "2026-05-18T12:00:00Z", updatedAt: nil),
            FoodEntry(id: "4", userId: "1", name: "Apple", calories: 95, protein: 0, fat: 0, carbs: 25, foodId: nil, grams: nil, unit: "g", categoryName: nil, categoryIcon: nil,imageUrl: nil, createdAt: "2026-05-18T12:00:00Z", updatedAt: nil),
            FoodEntry(id: "5", userId: "1", name: "Salmon", calories: 367, protein: 34, fat: 22, carbs: 0, foodId: nil, grams: nil, unit: "g", categoryName: nil,categoryIcon: nil, imageUrl: nil, createdAt: "2026-05-18T14:00:00Z", updatedAt: nil),
            FoodEntry(id: "6", userId: "1", name: "Broccoli", calories: 55, protein: 4, fat: 1, carbs: 11, foodId: nil, grams: nil, unit: "g", categoryName: nil,categoryIcon: nil, imageUrl: nil, createdAt: "2026-05-18T14:00:00Z", updatedAt: nil),
            FoodEntry(id: "7", userId: "1", name: "Greek yogurt", calories: 150, protein: 15, fat: 4, carbs: 10, foodId: nil, grams: nil, unit: "g", categoryName: nil,categoryIcon: nil, imageUrl: nil, createdAt: "2026-05-18T19:00:00Z", updatedAt: nil)
        ]
    }
    func getFoodByDate(date: String) async throws -> [FoodEntry] {
        try await getTodayFood()
    }
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
    ) async throws -> FoodEntry {
        FoodEntry(id: id, userId: "1", name: name ?? "Updated", calories: calories ?? 100, protein: protein, fat: fat, carbs: carbs, foodId: foodId, grams: grams, unit: unit ?? "g", categoryName: categoryName,categoryIcon: nil, imageUrl: nil, createdAt: "2026-05-18T10:00:00Z", updatedAt: "2026-05-18T11:00:00Z")
    }
    func deleteFoodEntry(id: String, date: String? = nil) async throws { }
    
    func searchFood(query: String, limit: Int, offset: Int) async throws -> FoodSearchResponse {
        FoodSearchResponse(
            foods: [],
            suggestedGrams: nil,
            suggestedUnit: nil,
            hasMore: false,
            total: 0,
            offset: offset,
            limit: limit
        )
    }
    func getFoods(
        categoryId: String?,
        personalOnly: Bool = false,
        limit: Int,
        offset: Int
    ) async throws -> [CatalogFoodCategoryGroup] {
        let foods = try await getPopularFood()
        let categoryFilteredFoods = categoryId.map { id in
            foods.filter { $0.categoryId == id }
        } ?? foods
        let filteredFoods = personalOnly
            ? categoryFilteredFoods.filter { $0.source == "user" }
            : categoryFilteredFoods

        return [
            CatalogFoodCategoryGroup(
                id: categoryId ?? "",
                name: categoryId == nil ? "All Foods" : "Category",
                icon: nil,
                foods: Array(filteredFoods.dropFirst(offset).prefix(limit))
            )
        ]
    }

    func bulkUpdateFoodCategory(
        foodIds: [String],
        categoryId: String?
    ) async throws -> BulkUpdateFoodCategoryResponse {
        BulkUpdateFoodCategoryResponse(
            updatedCount: foodIds.count,
            foodIds: foodIds,
            categoryId: categoryId
        )
    }

    func selectFood(id: String) async throws { }
    func getPopularFood() async throws -> [CatalogFood] {
        [
            // Fruits (system-fruits)
            CatalogFood(id: "f1", name: "Apple", categoryId: "system-fruits", categoryName: "Fruits", brand: nil, caloriesPer100g: 52, proteinPer100g: 0.3, fatPer100g: 0.2, carbsPer100g: 14, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "f2", name: "Banana", categoryId: "system-fruits", categoryName: "Fruits", brand: nil, caloriesPer100g: 89, proteinPer100g: 1.1, fatPer100g: 0.3, carbsPer100g: 23, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "f3", name: "Orange", categoryId: "system-fruits", categoryName: "Fruits", brand: nil, caloriesPer100g: 47, proteinPer100g: 0.9, fatPer100g: 0.1, carbsPer100g: 12, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "f4", name: "Strawberry", categoryId: "system-fruits", categoryName: "Fruits", brand: nil, caloriesPer100g: 32, proteinPer100g: 0.7, fatPer100g: 0.3, carbsPer100g: 8, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "f5", name: "Grapes", categoryId: "system-fruits", categoryName: "Fruits", brand: nil, caloriesPer100g: 69, proteinPer100g: 0.7, fatPer100g: 0.2, carbsPer100g: 18, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "f6", name: "dfdf", categoryId: "system-fruits", categoryName: "Protein", brand: nil, caloriesPer100g: 155, proteinPer100g: 13, fatPer100g: 11, carbsPer100g: 1.1, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "f7", name: "fgfg", categoryId: "system-fruits", categoryName: "Protein", brand: nil, caloriesPer100g: 155, proteinPer100g: 13, fatPer100g: 11, carbsPer100g: 1.1, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),

            // Protein (system-protein)
            CatalogFood(id: "p1", name: "Chicken Breast", categoryId: "system-protein", categoryName: "Protein", brand: nil, caloriesPer100g: 165, proteinPer100g: 31, fatPer100g: 3.6, carbsPer100g: 0, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "p2", name: "Beef Steak", categoryId: "system-protein", categoryName: "Protein", brand: nil, caloriesPer100g: 250, proteinPer100g: 26, fatPer100g: 15, carbsPer100g: 0, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "p3", name: "Salmon", categoryId: "system-protein", categoryName: "Protein", brand: nil, caloriesPer100g: 206, proteinPer100g: 22, fatPer100g: 12, carbsPer100g: 0, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "p4", name: "Eggs", categoryId: "system-protein", categoryName: "Protein", brand: nil, caloriesPer100g: 155, proteinPer100g: 13, fatPer100g: 11, carbsPer100g: 1.1, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),

            // Dairy (system-dairy)
            CatalogFood(id: "d1", name: "Greek Yogurt", categoryId: "system-dairy", categoryName: "Dairy", brand: nil, caloriesPer100g: 59, proteinPer100g: 10, fatPer100g: 0.4, carbsPer100g: 4, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "d2", name: "Milk", categoryId: "system-dairy", categoryName: "Dairy", brand: nil, caloriesPer100g: 42, proteinPer100g: 3.4, fatPer100g: 1, carbsPer100g: 5, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "d3", name: "Cheese", categoryId: "system-dairy", categoryName: "Dairy", brand: nil, caloriesPer100g: 400, proteinPer100g: 25, fatPer100g: 33, carbsPer100g: 1, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),

            // Vegetables (system-vegetables)
            CatalogFood(id: "v1", name: "Broccoli", categoryId: "system-vegetables", categoryName: "Vegetables", brand: nil, caloriesPer100g: 34, proteinPer100g: 2.8, fatPer100g: 0.4, carbsPer100g: 7, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "v2", name: "Carrot", categoryId: "system-vegetables", categoryName: "Vegetables", brand: nil, caloriesPer100g: 41, proteinPer100g: 0.9, fatPer100g: 0.2, carbsPer100g: 10, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "v3", name: "Spinach", categoryId: "system-vegetables", categoryName: "Vegetables", brand: nil, caloriesPer100g: 23, proteinPer100g: 2.9, fatPer100g: 0.4, carbsPer100g: 3.6, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),

            // Grains (system-grains)
            CatalogFood(id: "g1", name: "Brown Rice", categoryId: "system-grains", categoryName: "Grains", brand: nil, caloriesPer100g: 111, proteinPer100g: 3, fatPer100g: 1, carbsPer100g: 23, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "g2", name: "Oatmeal", categoryId: "system-grains", categoryName: "Grains", brand: nil, caloriesPer100g: 71, proteinPer100g: 2.5, fatPer100g: 1.4, carbsPer100g: 12, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "g3", name: "Quinoa", categoryId: "system-grains", categoryName: "Grains", brand: nil, caloriesPer100g: 120, proteinPer100g: 4.4, fatPer100g: 1.9, carbsPer100g: 21, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),

            // Breakfast (personal-breakfast)
            CatalogFood(id: "pb1", name: "Oatmeal Bowl", categoryId: "personal-breakfast", categoryName: "Breakfast", brand: nil, caloriesPer100g: 71, proteinPer100g: 2.5, fatPer100g: 1.4, carbsPer100g: 12, barcode: nil, imageUrl: nil, source: "user", createdBy: "user-1", createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "pb2", name: "Pancakes", categoryId: "personal-breakfast", categoryName: "Breakfast", brand: nil, caloriesPer100g: 227, proteinPer100g: 6, fatPer100g: 9, carbsPer100g: 32, barcode: nil, imageUrl: nil, source: "user", createdBy: "user-1", createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "pb3", name: "Scrambled Eggs", categoryId: "personal-breakfast", categoryName: "Breakfast", brand: nil, caloriesPer100g: 149, proteinPer100g: 11, fatPer100g: 10, carbsPer100g: 1.4, barcode: nil, imageUrl: nil, source: "user", createdBy: "user-1", createdAt: "", updatedAt: "", servings: nil),

            // Home Cooking (personal-home)
            CatalogFood(id: "ph1", name: "Pasta Carbonara", categoryId: "personal-home", categoryName: "Home Cooking", brand: nil, caloriesPer100g: 174, proteinPer100g: 7, fatPer100g: 7, carbsPer100g: 26, barcode: nil, imageUrl: nil, source: "user", createdBy: "user-1", createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "ph2", name: "Chicken Soup", categoryId: "personal-home", categoryName: "Home Cooking", brand: nil, caloriesPer100g: 67, proteinPer100g: 5, fatPer100g: 2, carbsPer100g: 6, barcode: nil, imageUrl: nil, source: "user", createdBy: "user-1", createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "ph3", name: "Beef Stew", categoryId: "personal-home", categoryName: "Home Cooking", brand: nil, caloriesPer100g: 123, proteinPer100g: 9, fatPer100g: 5, carbsPer100g: 12, barcode: nil, imageUrl: nil, source: "user", createdBy: "user-1", createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "ph4", name: "Roasted Vegetables", categoryId: "personal-home", categoryName: "Home Cooking", brand: nil, caloriesPer100g: 89, proteinPer100g: 3, fatPer100g: 4, carbsPer100g: 12, barcode: nil, imageUrl: nil, source: "user", createdBy: "user-1", createdAt: "", updatedAt: "", servings: nil),

            // Dinner (personal-dinner)
            CatalogFood(id: "pd1", name: "Grilled Salmon", categoryId: "personal-dinner", categoryName: "Dinner", brand: nil, caloriesPer100g: 206, proteinPer100g: 22, fatPer100g: 12, carbsPer100g: 0, barcode: nil, imageUrl: nil, source: "user", createdBy: "user-1", createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "pd2", name: "Steak with Potatoes", categoryId: "personal-dinner", categoryName: "Dinner", brand: nil, caloriesPer100g: 312, proteinPer100g: 26, fatPer100g: 18, carbsPer100g: 18, barcode: nil, imageUrl: nil, source: "user", createdBy: "user-1", createdAt: "", updatedAt: "", servings: nil),

            // Drinks (personal-drinks)
            CatalogFood(id: "dr1", name: "Coffee", categoryId: "personal-drinks", categoryName: "Drinks", brand: nil, caloriesPer100g: 2, proteinPer100g: 0.1, fatPer100g: 0, carbsPer100g: 0, barcode: nil, imageUrl: nil, source: "user", createdBy: "user-1", createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "dr2", name: "Orange Juice", categoryId: "personal-drinks", categoryName: "Drinks", brand: nil, caloriesPer100g: 47, proteinPer100g: 0.7, fatPer100g: 0.1, carbsPer100g: 12, barcode: nil, imageUrl: nil, source: "user", createdBy: "user-1", createdAt: "", updatedAt: "", servings: nil),
        ]
    }
    func getFoodById(_ id: String) async throws -> CatalogFood {
        CatalogFood(id: id, name: "Mock Food", categoryId: "242542", categoryName: "gjhgh", brand: nil, caloriesPer100g: 100, proteinPer100g: 10, fatPer100g: 5, carbsPer100g: 10, barcode: nil, imageUrl: nil, source: "user", createdBy: nil, createdAt: "", updatedAt: "", servings: nil)
    }
    func createCatalogFood(_ request: CreateCatalogFoodRequest) async throws -> CatalogFood {
        CatalogFood(id: UUID().uuidString, name: request.name, categoryId: request.categoryId, categoryName: nil, brand: nil, caloriesPer100g: request.caloriesPer100g, proteinPer100g: request.proteinPer100g, fatPer100g: request.fatPer100g, carbsPer100g: request.carbsPer100g, barcode: request.barcode, imageUrl: request.imageUrl, source: "user", createdBy: nil, createdAt: "", updatedAt: "", servings: request.servings?.map { FoodServing(id: UUID().uuidString, foodId: "", name: $0.name, grams: $0.grams, createdAt: nil) })
    }
    func getCategories() async throws -> [FoodCategory] {
        [
            FoodCategory(id: "system-fruits", name: "Fruits", icon: "leaf.fill", color: "#84CC16", createdBy: nil, createdAt: "2026-01-01T00:00:00Z", foodCount: 5),
            FoodCategory(id: "system-protein", name: "Protein", icon: "fish.fill", color: "#EF4444", createdBy: nil, createdAt: "2026-01-01T00:00:00Z", foodCount: 4),
            FoodCategory(id: "system-dairy", name: "Dairy", icon: "cup.and.saucer.fill", color: "#3B82F6", createdBy: nil, createdAt: "2026-01-01T00:00:00Z", foodCount: 3),
            FoodCategory(id: "system-vegetables", name: "Vegetables", icon: "carrot.fill", color: "#F59E0B", createdBy: nil, createdAt: "2026-01-01T00:00:00Z", foodCount: 3),
            FoodCategory(id: "system-grains", name: "Grains", icon: "bread.fill", color: "#A855F7", createdBy: nil, createdAt: "2026-01-01T00:00:00Z", foodCount: 3),
            FoodCategory(id: "system-snacks", name: "Snacks", icon: "takeoutbag.and.cup.and.straw", color: "#EC4899", createdBy: nil, createdAt: "2026-01-01T00:00:00Z", foodCount: 2),
            FoodCategory(id: "system-beverages", name: "Beverages", icon: "cup.fill", color: "#06B6D4", createdBy: nil, createdAt: "2026-01-01T00:00:00Z", foodCount: 2),
            FoodCategory(id: "personal-breakfast", name: "Breakfast", icon: "sunrise.fill", color: "#F97316", createdBy: "1", createdAt: "2026-05-18T08:00:00Z", foodCount: 3),
            FoodCategory(id: "personal-home", name: "Home Cooking", icon: "house.fill", color: "#10B981", createdBy: "1", createdAt: "2026-05-18T08:00:00Z", foodCount: 4),
            FoodCategory(id: "personal-dinner", name: "Dinner", icon: "moon.fill", color: "#6366F1", createdBy: "1", createdAt: "2026-05-18T09:00:00Z", foodCount: 2),
            FoodCategory(id: "personal-drinks", name: "Drinks", icon: "cup.and.saucer.fill", color: "#EC4899", createdBy: "1", createdAt: "2026-05-18T10:00:00Z", foodCount: 2),
        ]
    }
    func createCategory(name: String, icon: String?, color: String?) async throws -> FoodCategory {
        FoodCategory(id: UUID().uuidString, name: name, icon: icon, color: color, createdBy: "1", createdAt: "", foodCount: 0)
    }
    func updateCategory(id: String, name: String?, icon: String?, color: String?) async throws -> FoodCategory {
        let existing = try await getCategories().first { $0.id == id }
        return FoodCategory(
            id: id,
            name: name ?? existing?.name ?? "Category",
            icon: icon ?? existing?.icon,
            color: color ?? existing?.color,
            createdBy: existing?.createdBy ?? "1",
            createdAt: existing?.createdAt ?? "",
            foodCount: existing?.foodCount ?? 0
        )
    }
    func deleteCategory(id: String) async throws { }
    func uploadImage(_ data: Data) async throws -> String { "https://example.com/mock.jpg" }
    func analyzePhoto(_ data: Data) async throws -> [ScanAnalysisItem] { [] }
}

final class MockActivityService: ActivityServiceProtocol {
    func sync(entries: [DailyActivity]) async throws { }
    func send(entries: [DailyActivity]) async throws { }
    func getRange(from: String, to: String) async throws -> [ActivityDayPoint] {
        let cal = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = .current
        let start = df.date(from: from) ?? Date()
        let end = df.date(from: to) ?? Date()
        var points: [ActivityDayPoint] = []
        var day = start
        while day <= end {
            let consumed = Int.random(in: 1500...2500)
            let burned = Int.random(in: 300...800)
            points.append(ActivityDayPoint(
                date: df.string(from: day),
                steps: Int.random(in: 3000...12000),
                activeCalories: Double(burned),
                basalCalories: Double(Int.random(in: 1300...1900)),
                distanceMeters: Double(Int.random(in: 2000...9000)),
                caloriesConsumed: Double(consumed),
                netCalories: Double(consumed - burned)
            ))
            day = cal.date(byAdding: .day, value: 1, to: day) ?? day
        }
        return points
    }
}

@MainActor
final class MockActivitySync: ActivitySyncProtocol {
    var isSessionActive: Bool { false }
    var onActivityUpdate: ((DailyActivity) -> Void)?
    var goalsProvider: (() -> UserGoals?)?
    func start() {}
    func stop() {}
    func refresh() async {}
    func authorizationDidChange() {}
}

final class MockWaterService: WaterTrackingServiceProtocol {
    func createWaterEntry(amountMl: Int, date: String? = nil) async throws -> WaterEntry {
        WaterEntry(id: UUID().uuidString, userId: "1", amountMl: amountMl, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil)
    }
    func getTodayWater() async throws -> [WaterEntry] {
        [
            WaterEntry(id: "1", userId: "1", amountMl: 300, createdAt: "2026-05-18T08:00:00Z", updatedAt: nil),
            WaterEntry(id: "2", userId: "1", amountMl: 500, createdAt: "2026-05-18T10:30:00Z", updatedAt: nil),
            WaterEntry(id: "3", userId: "1", amountMl: 400, createdAt: "2026-05-18T12:00:00Z", updatedAt: nil),
            WaterEntry(id: "4", userId: "1", amountMl: 350, createdAt: "2026-05-18T15:00:00Z", updatedAt: nil),
            WaterEntry(id: "5", userId: "1", amountMl: 250, createdAt: "2026-05-18T18:00:00Z", updatedAt: nil),
            WaterEntry(id: "6", userId: "1", amountMl: 200, createdAt: "2026-05-18T21:00:00Z", updatedAt: nil)
        ]
    }
    func getWaterByDate(date: String) async throws -> [WaterEntry] {
        try await getTodayWater()
    }
    func deleteWaterEntry(id: String, date: String? = nil) async throws { }
}

final class MockDailySummaryService: DailySummaryServiceProtocol {
    func getTodayDailySummary() async throws -> DailySummary {
        DailySummary(id: "1", userId: "1", date: "2026-05-18", totalCalories: 1250, totalProtein: 85, totalFat: 42, totalCarbs: 120, totalWaterMl: 1750, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil)
    }
    func getDailySummaryByDate(date: String) async throws -> DailySummary {
        DailySummary(id: "2", userId: "1", date: date, totalCalories: 1500, totalProtein: 90, totalFat: 50, totalCarbs: 150, totalWaterMl: 2000, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil)
    }
    func getDashboardToday() async throws -> DashboardTodayResponse {
        try await DashboardTodayResponse(
            dailySummary: getTodayDailySummary(),
            foodEntries: MockFoodService().getTodayFood(),
            waterEntries: MockWaterService().getTodayWater()
        )
    }
    
    func getDailySummaryRange(from: String, to: String) async throws -> [DailySummary] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let fromDate = fmt.date(from: from),
              let toDate = fmt.date(from: to) else { return [] }
        var result: [DailySummary] = []
        var current = fromDate
        while current <= toDate {
            result.append(DailySummary(
                id: UUID().uuidString,
                userId: "1",
                date: fmt.string(from: current),
                totalCalories: Double.random(in: 1_500...2_500),
                totalProtein: Double.random(in: 60...120),
                totalFat: Double.random(in: 30...70),
                totalCarbs: Double.random(in: 100...200),
                totalWaterMl: Int.random(in: 1500...2500),
                createdAt: "2026-05-18T10:00:00Z",
                updatedAt: nil
            ))
            current = Calendar.current.date(byAdding: .day, value: 1, to: current)!
        }
        return result
    }
}

final class MockProfileService: ProfileServiceProtocol {
    func updateTimeZone(_ timeZone: String) async throws {}
    func getMyProfile() async throws -> UserProfile {
        UserProfile(id: UUID().uuidString, userId: "1", email: "test@example.com", firstName: "Artem", lastName: "Developer", weight: 82, height: 183, age: 24, gender: .male, goal: .gain, activityLevel: .high, preferredUnits: nil, timeZone: TimeZone.current.identifier, createdAt: nil, updatedAt: nil)
    }
    func createProfile(weight: Double, height: Int, age: Int, gender: Gender, goal: Goal, activityLevel: ActivityLevel, preferredUnits: PreferredUnits? = nil) async throws -> UserProfile {
        UserProfile(id: UUID().uuidString, userId: "1", email: "test@example.com", firstName: "Artem", lastName: "Developer", weight: weight, height: height, age: age, gender: gender, goal: goal, activityLevel: activityLevel, preferredUnits: preferredUnits, timeZone: TimeZone.current.identifier, createdAt: nil, updatedAt: nil)
    }
    func updateMyProfile(height: Int?, age: Int?, gender: Gender?, goal: Goal?, activityLevel: ActivityLevel?, preferredUnits: PreferredUnits? = nil) async throws -> UserProfile {
        UserProfile(id: UUID().uuidString, userId: "1", email: "test@example.com", firstName: "Artem", lastName: "Developer", weight: 82, height: height, age: age, gender: gender, goal: goal, activityLevel: activityLevel, preferredUnits: preferredUnits, timeZone: TimeZone.current.identifier, createdAt: nil, updatedAt: nil)
    }
    func deleteMyProfile() async throws { }
    func getWeightLogs(from: String?, to: String?) async throws -> [WeightLog] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let weights: [Double] = [80.0, 79.8, 79.9, 79.6, 79.7, 79.5, 79.4]
        return weights.enumerated().compactMap{index, kg in
            guard let date = Calendar.current.date(byAdding: .day, value: index - (weights.count - 1), to: Date())else { return nil }
            return WeightLog(
                id: "mock-wl-\(index)",
                weightKg: kg,
                entryDate: formatter.string(from: date),
                source: "manual"
            )
        }
    }
    func recordWeight(weightKg: Double) async throws -> WeightLog {
        WeightLog(id: UUID().uuidString, weightKg: weightKg, entryDate: ISO8601DateFormatter().string(from: Date()), source: "manual")
    }
    func deleteWeightLog(date: String) async throws { }
}

final class MockUserService: UserServiceProtocol {
    func getMe() async throws -> User {
        User(id: "1", email: "test@example.com", firstName: "Artem", lastName: "Developer")
    }
    func updateMe(email: String?, password: String?, firstName: String?, lastName: String?) async throws -> User {
        User(id: "1", email: email ?? "test@example.com", firstName: firstName ?? "Artem", lastName: lastName ?? "Developer")
    }
}


final class MockAuthService: AuthServiceProtocol {
    func changePassword(currentPassword: String, newPassword: String) async throws {
    }
    func register(email: String, password: String, firstName: String, lastName: String) async throws { }
    func login(email: String, password: String) async throws { }
    func signInWithGoogle(idToken: String) async throws { }
    func signInWithApple(identityToken: String, firstName: String?, lastName: String?) async throws { }
    func logout() async throws { }
    func logoutAll() async throws { }
}


final class MockAnalyticsService: AnalyticsServiceProtocol {
    func getWeekAnalytics() async throws -> AnalyticsResponse {
        makeMockResponse(period: "week")
    }
    func getMonthAnalytics() async throws -> AnalyticsResponse {
        makeMockResponse(period: "month")
    }
    func getCustomRange(from: String, to: String) async throws -> AnalyticsResponse {
        makeMockResponse(period: "custom")
    }
    private func makeMockResponse(period: String) -> AnalyticsResponse {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())
        let days = (0..<7).map { i in
            let d = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            return AnalyticsDay(
                date: fmt.string(from: d),
                calories: Double.random(in: 1_500...2_500),
                protein: Double.random(in: 60...120),
                fat: Double.random(in: 30...70),
                carbs: Double.random(in: 100...200),
                water: Int.random(in: 1500...2500),
                caloriesPct: Int.random(in: 60...110),
                proteinPct: Int.random(in: 40...100),
                fatPct: Int.random(in: 50...100),
                carbsPct: Int.random(in: 40...90),
                waterPct: Int.random(in: 50...100)
            )
        }
        return AnalyticsResponse(
            period: period,
            fromDate: today,
            toDate: today,
            averageCalories: 1_950.4,
            averageProtein: 90.2,
            averageFat: 50.5,
            averageCarbs: 150.1,
            averageWater: 2000,
            goalCalories: 2200,
            goalCaloriesPct: 89,
            goalProtein: 150,
            goalProteinPct: 60,
            goalFat: 65,
            goalFatPct: 77,
            goalCarbs: 250,
            goalCarbsPct: 60,
            goalWater: 3000,
            goalWaterPct: 67,
            avgSteps: 8600,
            avgActiveCalories: 430,
            goalSteps: 10000,
            goalStepsPct: 86,
            goalActiveCalories: 500,
            goalActiveCaloriesPct: 86,
            sleepTotalNights: 7,
            sleepNightsInRange: 4,
            workoutsDone: 3,
            workoutMinutes: 135,
            daysTracked: 5,
            totalDays: 7,
            streak: 3,
            streakStart: today,
            trend: .stable,
            daily: days
        )
    }
}

final class MockGoalsService: GoalsServiceProtocol {
    
    func personalizeGoals() async throws -> PersonalizeResult {
        .insufficientData
        
    }
    
    func getPersonalizationState() async throws -> PersonalizationState {
        PersonalizationState(
            pending: GoalRecommendation(
                id: "mock-rec-1",
                userId: "1",
                status: "pending",
                previousGoals: GoalMetrics(
                    dailyCaloriesGoal: 2200, dailyProteinGoal: 150,
                    dailyFatGoal: 65, dailyCarbsGoal: 250, dailyWaterGoal: 3000,
                    dailyStepsGoal: 8000, dailyActiveCaloriesGoal: 500,
                    weeklyWorkoutsGoal: 5, weeklyWorkoutMinutesGoal: 155,
                    nightlySleepMinMinutes: 234, nightlySleepMaxMinutes: 500
                ),
                recommendedGoals: GoalMetrics(
                    dailyCaloriesGoal: 2050, dailyProteinGoal: 160,
                    dailyFatGoal: 60, dailyCarbsGoal: 230, dailyWaterGoal: 3000,
                    dailyStepsGoal: 9000, dailyActiveCaloriesGoal: 550,
                    weeklyWorkoutsGoal: 6, weeklyWorkoutMinutesGoal: 180,
                    nightlySleepMinMinutes: 240, nightlySleepMaxMinutes: 510
                ),
                analysisPeriodStart: "2026-09-03",
                analysisPeriodEnd: "2026-09-17",
                reasons: [
                    "Your weekly calories were 10% below target",
                    "Your average sleep is shorter than the recommended range"
                ],
                confidence: RecommendationConfidence(
                    level: "high", dataQualityScore: 0.87, trackedDays: 14,
                    weightLogsCount: 0, activityDays: 12, workoutCount: 4,
                    sleepNights: 14, adherenceStepsPct: 0.72, weightTrendKgPerWeek: nil
                ),
                createdAt: "2026-09-17T08:00:00Z",
                expiresAt: "2026-09-24T08:00:00Z",
                acceptedAt: nil,
                dismissedAt: nil
            ),
            personalizationDue: false,
            nextAvailableAt: nil
        )
    }
    func dismissRecommendation(id: String) async throws -> DismissResult {
        DismissResult(dismissed: true)
    }
    
    func acceptRecommendation(id: String) async throws -> GoalMetrics {
        GoalMetrics(
            dailyCaloriesGoal: 2200,
            dailyProteinGoal: 150,
            dailyFatGoal: 65,
            dailyCarbsGoal: 250,
            dailyWaterGoal: 3000,
            dailyStepsGoal: 8000,
            dailyActiveCaloriesGoal: 500,
            weeklyWorkoutsGoal: 5,
            weeklyWorkoutMinutesGoal: 155,
            nightlySleepMinMinutes: 234,
            nightlySleepMaxMinutes: 500
        )
    }
    
    func getGoalHistory(
        date: String?,
        limit: Int?,
        cursor: String?
    ) async throws -> GoalHistoryPage {
        GoalHistoryPage(
            items: [
                GoalVersionEntry(
                    id: "v3",
                    startedAt: "2026-09-17T10:00:00Z",
                    endedAt: nil,
                    source: "personalized",
                    reason: "recommendation_accepted",
                    changes: [
                        GoalMetricChange(metric: "dailyCaloriesGoal", from: 2300, to: 2050),
                        GoalMetricChange(metric: "dailyProteinGoal", from: 150, to: 160),
                        GoalMetricChange(metric: "dailyFatGoal", from: 65, to: 60),
                        GoalMetricChange(metric: "dailyCarbsGoal", from: 250, to: 230),
                        GoalMetricChange(metric: "dailyStepsGoal", from: 8000, to: 9000)
                    ],
                    goal: GoalMetrics(
                        dailyCaloriesGoal: 2050,
                        dailyProteinGoal: 160,
                        dailyFatGoal: 60,
                        dailyCarbsGoal: 230,
                        dailyWaterGoal: 3000,
                        dailyStepsGoal: 9000,
                        dailyActiveCaloriesGoal: 550,
                        weeklyWorkoutsGoal: 6,
                        weeklyWorkoutMinutesGoal: 180,
                        nightlySleepMinMinutes: 240,
                        nightlySleepMaxMinutes: 510
                    )
                ),
                GoalVersionEntry(
                    id: "v2",
                    startedAt: "2026-09-10T10:00:00Z",
                    endedAt: "2026-09-17T10:00:00Z",
                    source: "user",
                    reason: "user_edit",
                    changes: [
                        GoalMetricChange(metric: "dailyCaloriesGoal", from: 2200, to: 2300)
                    ],
                    goal: GoalMetrics(
                        dailyCaloriesGoal: 2300,
                        dailyProteinGoal: 150,
                        dailyFatGoal: 65,
                        dailyCarbsGoal: 250,
                        dailyWaterGoal: 3000,
                        dailyStepsGoal: 8000,
                        dailyActiveCaloriesGoal: 500,
                        weeklyWorkoutsGoal: 5,
                        weeklyWorkoutMinutesGoal: 155,
                        nightlySleepMinMinutes: 234,
                        nightlySleepMaxMinutes: 500
                    )
                ),
                GoalVersionEntry(
                    id: "v1",
                    startedAt: "2026-09-01T10:00:00Z",
                    endedAt: "2026-09-10T10:00:00Z",
                    source: "initial",
                    reason: "initial_calculation",
                    changes: [
                        GoalMetricChange(metric: "dailyCaloriesGoal", from: nil, to: 2200),
                        GoalMetricChange(metric: "dailyProteinGoal", from: nil, to: 150),
                        GoalMetricChange(metric: "dailyFatGoal", from: nil, to: 65),
                        GoalMetricChange(metric: "dailyCarbsGoal", from: nil, to: 250),
                        GoalMetricChange(metric: "dailyWaterGoal", from: nil, to: 3000),
                        GoalMetricChange(metric: "dailyStepsGoal", from: nil, to: 8000),
                        GoalMetricChange(metric: "nightlySleepMinMinutes", from: nil, to: 234)
                    ],
                    goal: GoalMetrics(
                        dailyCaloriesGoal: 2200,
                        dailyProteinGoal: 150,
                        dailyFatGoal: 65,
                        dailyCarbsGoal: 250,
                        dailyWaterGoal: 3000,
                        dailyStepsGoal: 8000,
                        dailyActiveCaloriesGoal: 500,
                        weeklyWorkoutsGoal: 5,
                        weeklyWorkoutMinutesGoal: 155,
                        nightlySleepMinMinutes: 234,
                        nightlySleepMaxMinutes: 500
                    )
                )
            ],
            nextCursor: nil
        )
    }

    func getGoals(date: String? = nil) async throws -> UserGoals {
        UserGoals(
            id: "1",
            userId: "1",
            dailyCaloriesGoal: 2050,
            dailyProteinGoal: 160,
            dailyFatGoal: 60,
            dailyCarbsGoal: 230,
            dailyWaterGoal: 3000,
            dailyStepsGoal: 9000,
            dailyActiveCaloriesGoal: 550,
            weeklyWorkoutsGoal: 6,
            weeklyWorkoutMinutesGoal: 180,
            nightlySleepMinMinutes: 240,
            nightlySleepMaxMinutes: 510,
            source: "personalized",
            createdAt: nil,
            updatedAt: nil
        )
    }
    func updateGoals(calories: Double?, protein: Double?, fat: Double?, carbs: Double?, water: Int?, steps: Int?,activeCalories: Int?,workouts: Int?,workoutMinutes: Int?,sleepMinMinutes: Int?,sleepMaxMinutes: Int?) async throws -> UserGoals {
        try await getGoals()
    }
    func calculateGoals() async throws -> UserGoals {
        try await getGoals()
    }
    func resetGoalsToAutomatic() async throws -> UserGoals {
        try await getGoals()
    }
}

final class MockWorkoutService: WorkoutServiceProtocol {
    func sync(entries: [WorkoutSyncEntry]) async throws {}
    func getHistory(
        from: String?,
        to: String?,
        limit: Int?,
        offset: Int?
    ) async throws -> WorkoutHistoryResponse {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = .current
        guard let from, let to,
              let _ = df.date(from: from),
              let end = df.date(from: to) else {
            return WorkoutHistoryResponse(total: 0, workouts: [])
        }
        
        let cal = Calendar.current
        var workouts: [WorkoutSyncEntry] = []
        let templates: [(type: String, hour: Int, minute: Int, minutes: Int, kcal: Double, meters: Double?)] = [
            ("Running", 8, 30, 45, 340, 5200),
            ("Strength Training", 18, 0, 30, 240, nil),
            ("Cycling", 12, 0, 60, 420, 18000),
        ]
        for template in templates {
            var comps = cal.dateComponents([.year, .month, .day], from: end)
            comps.hour = template.hour
            comps.minute = template.minute
            guard let start = cal.date(from: comps) else { continue }
            workouts.append(WorkoutSyncEntry(
                healthKitWorkoutId: UUID().uuidString,
                type: template.type,
                startDate: WorkoutMapper.isoString(from: start),
                endDate: WorkoutMapper.isoString(from: start.addingTimeInterval(Double(template.minutes) * 60)),
                localDate: WorkoutMapper.localDayString(from: start),
                durationSeconds: Double(template.minutes) * 60,
                caloriesBurned: template.kcal,
                distanceMeters: template.meters,
                heartRateAvg: 130,
                heartRateMax: nil,
                heartRateMin: nil,
                avgSpeedMps: nil,
                maxSpeedMps: nil,
                avgCadence: nil,
                maxCadence: nil,
                avgPowerWatts: nil,
                maxPowerWatts: nil,
                elevationGainMeters: nil,
                steps: nil,
                indoor: nil,
                details: nil
            ))
        }
        return WorkoutHistoryResponse(total: workouts.count, workouts: workouts)
    }
    func deleteMissing(from startDate: String, to endDate: String, healthKitWorkoutIds: [String]) async throws {}
}

final class MockSleepService: SleepServiceProtocol {
    func sync(entries: [SleepSyncEntry]) async throws {}
    func getHistory(
        from: String?,
        to: String?,
        limit: Int?,
        offset: Int?
    ) async throws -> SleepHistoryResponse {
        let cal = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = .current
        let start = from.flatMap { df.date(from: $0) } ?? Date()
        let end = to.flatMap { df.date(from: $0) } ?? Date()
        
        var nights: [SleepSyncEntry] = []
        var day = start
        var index = 0
        while day <= end && nights.count < 10 {
            let inRange = index >= 1 && index <= 4
            let sleepStart = cal.date(byAdding: .hour, value: -8, to: day) ?? day
            nights.append(SleepSyncEntry(
                startDate: SleepMapper.isoString(from: sleepStart),
                endDate: SleepMapper.isoString(from: sleepStart.addingTimeInterval(inRange ? 8 * 3600 : 5 * 3600)),
                localDate: SleepMapper.localDayString(from: day),
                timeInBedSeconds: inRange ? 8 * 3600 : 5 * 3600,
                asleepSeconds: inRange ? 7 * 3600 : 3 * 3600,
                awakeSeconds: inRange ? 1 * 3600 : 2 * 3600,
                coreSeconds: nil,
                deepSeconds: nil,
                remSeconds: nil,
                unspecifiedSeconds: nil,
                awakenings: nil,
                onsetLatencySeconds: nil,
                efficiency: nil,
                segmentCount: nil,
                heartRateAvg: nil
            ))
            index += 1
            day = cal.date(byAdding: .day, value: 1, to: day) ?? day
        }
        return SleepHistoryResponse(total: nights.count, nights: nights)
    }
    func deleteMissing(from startDate: String, to endDate: String, keptStartDates: [String]) async throws {}
}

final class MockSleepHealthKit: SleepHealthKitServiceProtocol {
    var isAvailable: Bool { true }
    func permissionState() async -> HealthKitAuthorization { .authorized }
    
    func requestAuthorization() async throws {}
    
    func fetchHeartRateDuringSleep(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [SleepHeartRatePoint] {
        stride(
            from: startDate,
            through: endDate,
            by: 5 * 60
        ).map { date in
            SleepHeartRatePoint(
                date: date,
                bpm: Double.random(in: 52...68)
            )
        }
    }
    
    private func sampleNight(from startDate: Date, variation: Double) -> HealthKitSleep {
        let asleep = 7480 * (0.75 + variation)
        let core = asleep * 0.57
        let deep = asleep * 0.21
        let rem = asleep * 0.22
        let awake = 900 * (1 + variation)
        
        let nightStart = startDate.addingTimeInterval(7 * 3600)
        let nightEnd = startDate.addingTimeInterval(15 * 3600 + awake)
        
        return HealthKitSleep(
            id: mockNightID(start: nightStart, end: nightEnd),
            startDate: nightStart,
            endDate: nightEnd,
            timeInBedSeconds: asleep + awake,
            asleepSeconds: asleep,
            awakeSeconds: awake,
            coreSeconds: core,
            deepSeconds: deep,
            remSeconds: rem,
            unspecifiedSeconds: 0,
            awakenings: Int(2 + variation * 4),
            segmentCount: 12,
            onsetLatencySeconds: 1200,
            efficiency: asleep / (asleep + awake) * 100,
            heartRateAvg: 58 - variation * 3,
            segments: [
                SleepStageSegment(id: UUID(), startDate: startDate + 7 * 3600, endDate: startDate + 8 * 3600, stage: .inBed),
                SleepStageSegment(id: UUID(), startDate: startDate + 8 * 3600, endDate: startDate + 10 * 3600, stage: .core),
                SleepStageSegment(id: UUID(), startDate: startDate + 10 * 3600, endDate: startDate + 11 * 3600, stage: .deep),
                SleepStageSegment(id: UUID(), startDate: startDate + 10.5 * 3600, endDate: startDate + 10.7 * 3600, stage: .awake),
                SleepStageSegment(id: UUID(), startDate: startDate + 11 * 3600, endDate: startDate + 13 * 3600, stage: .rem),
                SleepStageSegment(id: UUID(), startDate: startDate + 13 * 3600, endDate: startDate + 14 * 3600, stage: .core),
                SleepStageSegment(id: UUID(), startDate: startDate + 14 * 3600, endDate: startDate + 15 * 3600, stage: .awake)
            ]
        )
    }
    
    func fetchSleep(from startDate: Date, to endDate: Date) async throws -> HealthKitSleep? {
        sampleNight(from: startDate, variation: 0.15)
    }
    
    
    
    func fetchNights(from startDate: Date, to endDate: Date) async throws -> [HealthKitSleep] {
        (0..<7).map { day in
            sampleNight(from: startDate.addingTimeInterval(TimeInterval(day) * 86_400), variation: Double(day) * 0.07)
        }
    }
}

private func mockNightID(start: Date, end: Date) -> UUID {
    let t1 = UInt64(start.timeIntervalSinceReferenceDate * 1000)
    let t2 = UInt64(end.timeIntervalSinceReferenceDate * 1000)
    var bytes = [UInt8](repeating: 0, count: 16)
    for i in 0..<8 {
        bytes[i] = UInt8((t1 >> (8 * (7 - i))) & 0xFF)
    }
    for i in 0..<8 {
        bytes[8 + i] = UInt8((t2 >> (8 * (7 - i))) & 0xFF)
    }
    bytes[6] = (bytes[6] & 0x0F) | 0x50
    bytes[8] = (bytes[8] & 0x3F) | 0x80
    return UUID(
        uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
    )
}

final class MockHealthKit: ActivityHealthKitServiceProtocol, WorkoutHealthKitServiceProtocol {
    var isAvailable: Bool { true }
    var onActivityChanged: (() -> Void)?
    
    static let sampleWorkout = HealthKitWorkout(
        id: UUID(),
        workoutType: "Running",
        startDate: Date().addingTimeInterval(-3600 * 30),
        endDate: Date().addingTimeInterval(-3600 * 30 + 2520),
        durationSeconds: 2520,
        caloriesBurned: 386,
        distanceMeters: 5200,
        heartRateAvg: 140,
        heartRateMax: 165,
        heartRateMin: 115
    )
    
    func requestAuthorization() async throws {}
    func fetchToday() async -> DailyActivity {
        DailyActivity(date: "", steps: 0, activeCalories: 0, basalCalories: 0, distanceMeters: 0)
    }
    func fetchRange(from startDate: Date, to endDate: Date) async throws -> [DailyActivity] {
        []
    }
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthKitWorkout] { [Self.sampleWorkout] }
    func fetchLatestWorkout() async throws -> HealthKitWorkout? { Self.sampleWorkout }
    func enableBackgroundDelivery() async throws {}
    func startObserving() {}
    func stopObserving() {}
    func completePendingObservations() {}
    func permissionState() async -> HealthKitAuthorization { .authorized }
    func fetchHeartRateWorkout(for workout: HealthKitWorkout) async throws -> [HeartRatePoint] {
        stride(from: workout.startDate, through: workout.endDate, by: 60).map { date in
            HeartRatePoint(startDate: date, bpm: Double(Int.random(in: 110...150)))
        }
    }
    
    func fetchWorkoutSeries(kind: WorkoutSeriesKind, workout: HealthKitWorkout) async throws -> [WorkoutSeriesPoint] {
        let startValue = kind == .speed ? 2.4 : kind == .cadence ? 84 : 210.0
        return stride(from: workout.startDate, through: workout.endDate, by: 120).enumerated().map { index, date in
            WorkoutSeriesPoint(
                date: date,
                value: startValue + sin(Double(index) * 0.5) * (kind == .speed ? 0.6 : 8)
            )
        }
    }
}
