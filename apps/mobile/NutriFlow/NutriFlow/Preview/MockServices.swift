import Foundation

final class MockTokenStorage: TokenStorageProtocol {
    private var accessToken: String?
    private var refreshToken: String?

    init(accessToken: String? = "mock_access_token", refreshToken: String? = "mock_refresh_token") {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    func saveAccessToken(_ token: String) throws { accessToken = token }
    func saveRefreshToken(_ token: String) throws { refreshToken = token }
    func getAccessToken() throws -> String? { accessToken }
    func getRefreshToken() throws -> String? { refreshToken }
    func clear() throws { accessToken = nil; refreshToken = nil }
}

final class MockFoodService: FoodServiceProtocol {
    func createFoodEntry(token: String, name: String, calories: Int, protein: Int?, fat: Int?, carbs: Int?) async throws -> FoodEntry {
        FoodEntry(id: UUID().uuidString, userId: "1", name: name, calories: calories, protein: protein, fat: fat, carbs: carbs, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil)
    }
    func getTodayFood(token: String) async throws -> [FoodEntry] {
        [
            FoodEntry(id: "1", userId: "1", name: "Chicken breast", calories: 165, protein: 31, fat: 4, carbs: 0, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil),
            FoodEntry(id: "2", userId: "1", name: "Rice", calories: 200, protein: 4, fat: 1, carbs: 45, createdAt: "2026-05-18T12:00:00Z", updatedAt: nil)
        ]
    }
    func deleteFoodEntry(token: String, id: String) async throws -> EmptyResponse {
        EmptyResponse()
    }
}

final class MockWaterService: WaterTrackingServiceProtocol {
    func createWaterEntry(token: String, amountMl: Int) async throws -> WaterEntry {
        WaterEntry(id: UUID().uuidString, userId: "1", amountMl: amountMl, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil)
    }
    func getTodayWater(token: String) async throws -> [WaterEntry] {
        [
            WaterEntry(id: "1", userId: "1", amountMl: 250, createdAt: "2026-05-18T08:00:00Z", updatedAt: nil),
            WaterEntry(id: "2", userId: "1", amountMl: 500, createdAt: "2026-05-18T10:30:00Z", updatedAt: nil)
        ]
    }
    func deleteWaterEntry(token: String, id: String) async throws -> EmptyResponse {
        EmptyResponse()
    }
}

final class MockDailySummaryService: DailySummaryServiceProtocol {
    func getTodayDailySummary(token: String) async throws -> DailySummary {
        DailySummary(id: "1", userId: "1", date: "2026-05-18", totalCalories: 1250, totalProtein: 85, totalFat: 42, totalCarbs: 120, totalWaterMl: 1750, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil)
    }
    func getDailySummaryByDate(token: String, date: String) async throws -> DailySummary {
        DailySummary(id: "2", userId: "1", date: date, totalCalories: 1500, totalProtein: 90, totalFat: 50, totalCarbs: 150, totalWaterMl: 2000, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil)
    }
    func getDailySummaryRange(token: String, from: String, to: String) async throws -> [DailySummary] {
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
    func getMyProfile(token: String) async throws -> UserProfile {
        UserProfile(id: UUID().uuidString, userId: "1", email: "test@example.com", firstName: "Artem", lastName: "Developer", weight: 82, height: 183, age: 24, goal: .gain, activityLevel: .high, createdAt: nil, updatedAt: nil)
    }
    func createProfile(token: String, weight: Double?, height: Int?, age: Int?, goal: Goal?, activityLevel: ActivityLevel?) async throws -> UserProfile {
        UserProfile(id: UUID().uuidString, userId: "1", email: "test@example.com", firstName: "Artem", lastName: "Developer", weight: weight, height: height, age: age, goal: goal, activityLevel: activityLevel, createdAt: nil, updatedAt: nil)
    }
    func updateMyProfile(token: String, weight: Double?, height: Int?, age: Int?, goal: Goal?, activityLevel: ActivityLevel?) async throws -> UserProfile {
        UserProfile(id: UUID().uuidString, userId: "1", email: "test@example.com", firstName: "Artem", lastName: "Developer", weight: weight, height: height, age: age, goal: goal, activityLevel: activityLevel, createdAt: nil, updatedAt: nil)
    }
    func deleteMyProfile(token: String) async throws -> EmptyResponse {
        EmptyResponse()
    }
}

final class MockUserService: UserServiceProtocol {
    func createUser(email: String, password: String, firstName: String?, lastName: String?) async throws -> User {
        User(id: "1", email: email, firstName: firstName ?? "", lastName: lastName ?? "")
    }
    func getUsers(token: String) async throws -> [User] {
        []
    }
    func getMe(token: String) async throws -> User {
        User(id: "1", email: "test@example.com", firstName: "Artem", lastName: "Developer")
    }
    func updateMe(token: String, email: String?, password: String?, firstName: String?, lastName: String?) async throws -> User {
        User(id: "1", email: email ?? "test@example.com", firstName: firstName ?? "Artem", lastName: lastName ?? "Developer")
    }
}

final class MockAuthService: AuthServiceProtocol {
    func register(email: String, password: String, firstName: String, lastName: String) async throws -> AuthTokensResponse {
        AuthTokensResponse(accessToken: "mock_access_token", refreshToken: "mock_refresh_token")
    }
    func login(email: String, password: String) async throws -> AuthTokensResponse {
        AuthTokensResponse(accessToken: "mock_access_token", refreshToken: "mock_refresh_token")
    }
    func refresh(refreshToken: String) async throws -> AuthTokensResponse {
        AuthTokensResponse(accessToken: "new_mock_access_token", refreshToken: "new_mock_refresh_token")
    }
    func logout(accessToken: String) async throws -> LogoutResponse {
        LogoutResponse(message: "Logged out")
    }
    func logoutAll(accessToken: String) async throws -> LogoutResponse {
        LogoutResponse(message: "Logged out from all devices")
    }
}