import Foundation

final class GuestAnalyticsService: AnalyticsServiceProtocol {
    private let summaryService: GuestDailySummaryService
    private let store: GuestStore

    init(summaryService: GuestDailySummaryService, store: GuestStore) {
        self.summaryService = summaryService
        self.store = store
    }

    func getWeekAnalytics() async throws -> AnalyticsResponse {
        try await todayOnlyResponse()
    }

    func getMonthAnalytics() async throws -> AnalyticsResponse {
        try await todayOnlyResponse()
    }

    func getCustomRange(from: String, to: String) async throws -> AnalyticsResponse {
        try await todayOnlyResponse()
    }

    private func todayOnlyResponse() async throws -> AnalyticsResponse {
        let summary = try await summaryService.getTodayDailySummary()
        return AnalyticsResponse(
            period: "today",
            fromDate: store.todayDate,
            toDate: store.todayDate,
            averageCalories: summary.totalCalories,
            averageProtein: summary.totalProtein,
            averageFat: summary.totalFat,
            averageCarbs: summary.totalCarbs,
            averageWater: summary.totalWaterMl,
            goalCalories: 2200,
            goalCaloriesPct: summary.totalCalories > 0 ? min(100, (summary.totalCalories * 100) / 2200) : nil,
            goalProtein: 150,
            goalProteinPct: summary.totalProtein > 0 ? min(100, (summary.totalProtein * 100) / 150) : nil,
            goalFat: 65,
            goalFatPct: summary.totalFat > 0 ? min(100, (summary.totalFat * 100) / 65) : nil,
            goalCarbs: 250,
            goalCarbsPct: summary.totalCarbs > 0 ? min(100, (summary.totalCarbs * 100) / 250) : nil,
            goalWater: 3000,
            goalWaterPct: summary.totalWaterMl > 0 ? min(100, (summary.totalWaterMl * 100) / 3000) : nil,
            daysTracked: summary.totalCalories > 0 ? 1 : 0,
            totalDays: 1,
            streak: summary.totalCalories > 0 ? 1 : 0,
            streakStart: summary.totalCalories > 0 ? store.todayDate : nil,
            trend: .insufficientData,
            daily: [
                AnalyticsDay(
                    date: store.todayDate,
                    calories: summary.totalCalories,
                    protein: summary.totalProtein,
                    fat: summary.totalFat,
                    carbs: summary.totalCarbs,
                    water: summary.totalWaterMl,
                    caloriesPct: summary.totalCalories > 0 ? min(100, (summary.totalCalories * 100) / 2200) : 0,
                    proteinPct: summary.totalProtein > 0 ? min(100, (summary.totalProtein * 100) / 150) : 0,
                    fatPct: summary.totalFat > 0 ? min(100, (summary.totalFat * 100) / 65) : 0,
                    carbsPct: summary.totalCarbs > 0 ? min(100, (summary.totalCarbs * 100) / 250) : 0,
                    waterPct: summary.totalWaterMl > 0 ? min(100, (summary.totalWaterMl * 100) / 3000) : 0
                )
            ]
        )
    }
}
