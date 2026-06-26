import Foundation

final class GuestDailySummaryService: DailySummaryServiceProtocol {
    private let store: GuestStore

    init(store: GuestStore) {
        self.store = store
    }

    func getTodayDailySummary() async throws -> DailySummary {
        computeSummary(date: store.todayDate, food: store.todayFood, water: store.todayWater)
    }

    func getDailySummaryByDate(date: String) async throws -> DailySummary {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())
        if date == today {
            return try await getTodayDailySummary()
        }
        return DailySummary(id: nil, userId: nil, date: date, totalCalories: 0, totalProtein: 0, totalFat: 0, totalCarbs: 0, totalWaterMl: 0, createdAt: nil, updatedAt: nil)
    }

    func getDailySummaryRange(from: String, to: String) async throws -> [DailySummary] {
        try await [getTodayDailySummary()]
    }

    func getDashboardToday() async throws -> DashboardTodayResponse {
        let summary = try await getTodayDailySummary()
        return DashboardTodayResponse(
            dailySummary: summary,
            foodEntries: store.todayFood,
            waterEntries: store.todayWater
        )
    }

    private func computeSummary(date: String, food: [FoodEntry], water: [WaterEntry]) -> DailySummary {
        DailySummary(
            id: food.isEmpty && water.isEmpty ? nil : "guest_\(date)",
            userId: nil,
            date: date,
            totalCalories: food.reduce(0) { $0 + $1.calories },
            totalProtein: food.reduce(0) { $0 + ($1.protein ?? 0) },
            totalFat: food.reduce(0) { $0 + ($1.fat ?? 0) },
            totalCarbs: food.reduce(0) { $0 + ($1.carbs ?? 0) },
            totalWaterMl: water.reduce(0) { $0 + $1.amountMl },
            createdAt: nil,
            updatedAt: nil
        )
    }
}
