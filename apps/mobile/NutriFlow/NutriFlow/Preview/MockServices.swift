import Foundation

final class MockFoodService: FoodServiceProtocol {
    func createFoodEntry(name: String, calories: Int, protein: Int?, fat: Int?, carbs: Int?, foodId: String? = nil, grams: Int? = nil, unit: String? = nil, categoryName: String? = nil, imageUrl: String? = nil, date: String? = nil) async throws -> FoodEntry {
        FoodEntry(id: UUID().uuidString, userId: "1", name: name, calories: calories, protein: protein, fat: fat, carbs: carbs, foodId: foodId, grams: grams, unit: unit ?? "g", categoryName: categoryName, imageUrl: imageUrl, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil)
    }
    func getTodayFood() async throws -> [FoodEntry] {
        [
            FoodEntry(id: "1", userId: "1", name: "Oatmeal", calories: 320, protein: 12, fat: 6, carbs: 56, foodId: nil, grams: nil, unit: "g", categoryName: nil, imageUrl: nil, createdAt: "2026-05-18T08:00:00Z", updatedAt: nil),
            FoodEntry(id: "2", userId: "1", name: "Chicken breast", calories: 165, protein: 31, fat: 4, carbs: 0, foodId: nil, grams: nil, unit: "g", categoryName: nil, imageUrl: nil, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil),
            FoodEntry(id: "3", userId: "1", name: "Rice", calories: 200, protein: 4, fat: 1, carbs: 45, foodId: nil, grams: nil, unit: "g", categoryName: nil, imageUrl: nil, createdAt: "2026-05-18T12:00:00Z", updatedAt: nil),
            FoodEntry(id: "4", userId: "1", name: "Apple", calories: 95, protein: 0, fat: 0, carbs: 25, foodId: nil, grams: nil, unit: "g", categoryName: nil, imageUrl: nil, createdAt: "2026-05-18T12:00:00Z", updatedAt: nil),
            FoodEntry(id: "5", userId: "1", name: "Salmon", calories: 367, protein: 34, fat: 22, carbs: 0, foodId: nil, grams: nil, unit: "g", categoryName: nil, imageUrl: nil, createdAt: "2026-05-18T14:00:00Z", updatedAt: nil),
            FoodEntry(id: "6", userId: "1", name: "Broccoli", calories: 55, protein: 4, fat: 1, carbs: 11, foodId: nil, grams: nil, unit: "g", categoryName: nil, imageUrl: nil, createdAt: "2026-05-18T14:00:00Z", updatedAt: nil),
            FoodEntry(id: "7", userId: "1", name: "Greek yogurt", calories: 150, protein: 15, fat: 4, carbs: 10, foodId: nil, grams: nil, unit: "g", categoryName: nil, imageUrl: nil, createdAt: "2026-05-18T19:00:00Z", updatedAt: nil)
        ]
    }
    func getFoodByDate(date: String) async throws -> [FoodEntry] {
        try await getTodayFood()
    }
    func updateFoodEntry(
        id: String,
        name: String?,
        calories: Int?,
        protein: Int?,
        fat: Int?,
        carbs: Int?,
        grams: Int?,
        foodId: String?,
        date: String?,
        imageUrl: String?,
        categoryName: String?
    ) async throws -> FoodEntry {
        FoodEntry(id: id, userId: "1", name: name ?? "Updated", calories: calories ?? 100, protein: protein, fat: fat, carbs: carbs, foodId: foodId, grams: grams, unit: "g", categoryName: categoryName, imageUrl: nil, createdAt: "2026-05-18T10:00:00Z", updatedAt: "2026-05-18T11:00:00Z")
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
    func selectFood(id: String) async throws { }
    func getPopularFood() async throws -> [CatalogFood] {
        [
            CatalogFood(id: "1", name: "Apple", categoryId: "1", categoryName: "Fruits", brand: nil, caloriesPer100g: 52, proteinPer100g: nil, fatPer100g: nil, carbsPer100g: 14, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "2", name: "Banana", categoryId: "1", categoryName: "Fruits", brand: nil, caloriesPer100g: 89, proteinPer100g: 1, fatPer100g: nil, carbsPer100g: 23, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "3", name: "Chicken Breast", categoryId: "2", categoryName: "Meat", brand: nil, caloriesPer100g: 165, proteinPer100g: 31, fatPer100g: 4, carbsPer100g: nil, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "4", name: "Brown Rice", categoryId: "3", categoryName: "Grains", brand: nil, caloriesPer100g: 111, proteinPer100g: 3, fatPer100g: 1, carbsPer100g: 23, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),
            CatalogFood(id: "5", name: "Greek Yogurt", categoryId: "4", categoryName: "Dairy", brand: nil, caloriesPer100g: 59, proteinPer100g: 10, fatPer100g: nil, carbsPer100g: 4, barcode: nil, imageUrl: nil, source: "system", createdBy: nil, createdAt: "", updatedAt: "", servings: nil),
        ]
    }
    func getFoodById(_ id: String) async throws -> CatalogFood {
        CatalogFood(id: id, name: "Mock Food", categoryId: "242542", categoryName: "gjhgh", brand: nil, caloriesPer100g: 100, proteinPer100g: 10, fatPer100g: 5, carbsPer100g: 10, barcode: nil, imageUrl: nil, source: "user", createdBy: nil, createdAt: "", updatedAt: "", servings: nil)
    }
    func createCatalogFood(_ request: CreateCatalogFoodRequest) async throws -> CatalogFood {
        CatalogFood(id: UUID().uuidString, name: request.name, categoryId: request.categoryId, categoryName: nil, brand: nil, caloriesPer100g: request.caloriesPer100g, proteinPer100g: request.proteinPer100g, fatPer100g: request.fatPer100g, carbsPer100g: request.carbsPer100g, barcode: request.barcode, imageUrl: request.imageUrl, source: "user", createdBy: nil, createdAt: "", updatedAt: "", servings: request.servings?.map { FoodServing(id: UUID().uuidString, foodId: "", name: $0.name, grams: $0.grams, createdAt: nil) })
    }
    func getCategories() async throws -> [FoodCategory] { [] }
    func uploadImage(_ data: Data) async throws -> String { "https://example.com/mock.jpg" }
    func analyzePhoto(_ data: Data) async throws -> [FoodAnalysisItem] { [] }
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
                totalCalories: Int.random(in: 1500...2500),
                totalProtein: Int.random(in: 60...120),
                totalFat: Int.random(in: 30...70),
                totalCarbs: Int.random(in: 100...200),
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
    func getMyProfile() async throws -> UserProfile {
        UserProfile(id: UUID().uuidString, userId: "1", email: "test@example.com", firstName: "Artem", lastName: "Developer", weight: 82, height: 183, age: 24, gender: .male, goal: .gain, activityLevel: .high, preferredUnits: nil, createdAt: nil, updatedAt: nil)
    }
    func createProfile(weight: Double?, height: Int?, age: Int?, gender: Gender?, goal: Goal?, activityLevel: ActivityLevel?, preferredUnits: PreferredUnits? = nil) async throws -> UserProfile {
        UserProfile(id: UUID().uuidString, userId: "1", email: "test@example.com", firstName: "Artem", lastName: "Developer", weight: weight, height: height, age: age, gender: gender, goal: goal, activityLevel: activityLevel, preferredUnits: preferredUnits, createdAt: nil, updatedAt: nil)
    }
    func updateMyProfile(weight: Double?, height: Int?, age: Int?, gender: Gender?, goal: Goal?, activityLevel: ActivityLevel?, preferredUnits: PreferredUnits? = nil) async throws -> UserProfile {
        UserProfile(id: UUID().uuidString, userId: "1", email: "test@example.com", firstName: "Artem", lastName: "Developer", weight: weight, height: height, age: age, gender: gender, goal: goal, activityLevel: activityLevel, preferredUnits: preferredUnits, createdAt: nil, updatedAt: nil)
    }
    func deleteMyProfile() async throws { }
}

final class MockUserService: UserServiceProtocol {
    func createUser(email: String, password: String, firstName: String?, lastName: String?) async throws -> User {
        User(id: "1", email: email, firstName: firstName ?? "", lastName: lastName ?? "")
    }
    func getUsers() async throws -> [User] { [] }
    func getMe() async throws -> User {
        User(id: "1", email: "test@example.com", firstName: "Artem", lastName: "Developer")
    }
    func updateMe(email: String?, password: String?, firstName: String?, lastName: String?) async throws -> User {
        User(id: "1", email: email ?? "test@example.com", firstName: firstName ?? "Artem", lastName: lastName ?? "Developer")
    }
}

    
final class MockAuthService: AuthServiceProtocol {
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
                calories: Int.random(in: 1500...2500),
                protein: Int.random(in: 60...120),
                fat: Int.random(in: 30...70),
                carbs: Int.random(in: 100...200),
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
            averageCalories: 1950,
            averageProtein: 90,
            averageFat: 50,
            averageCarbs: 150,
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
    func getGoals() async throws -> UserGoals {
        UserGoals(
            id: "1",
            userId: "1",
            dailyCaloriesGoal: 2200,
            dailyProteinGoal: 150,
            dailyFatGoal: 65,
            dailyCarbsGoal: 250,
            dailyWaterGoal: 3000,
            source: "auto",
            createdAt: nil,
            updatedAt: nil
        )
    }
    func updateGoals(calories: Int?, protein: Int?, fat: Int?, carbs: Int?, water: Int?) async throws -> UserGoals {
        try await getGoals()
    }
    func calculateGoals() async throws -> UserGoals {
        try await getGoals()
    }
}
