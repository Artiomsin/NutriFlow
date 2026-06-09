import Foundation

enum TrendType: String, Codable {
    case increasing
    case decreasing
    case stable
    case insufficientData = "insufficient_data"
}

struct AnalyticsResponse: Codable {
    let period: String
    let fromDate: String
    let toDate: String

    let averageCalories: Int
    let averageProtein: Int
    let averageFat: Int
    let averageCarbs: Int
    let averageWater: Int

    let goalCalories: Int?
    let goalCaloriesPct: Int?
    let goalProtein: Int?
    let goalProteinPct: Int?
    let goalFat: Int?
    let goalFatPct: Int?
    let goalCarbs: Int?
    let goalCarbsPct: Int?
    let goalWater: Int?
    let goalWaterPct: Int?

    let daysTracked: Int
    let totalDays: Int

    let streak: Int
    let streakStart: String?
    let trend: TrendType

    let daily: [AnalyticsDay]
}

struct AnalyticsDay: Codable {
    let date: String
    let calories: Int
    let protein: Int
    let fat: Int
    let carbs: Int
    let water: Int

    let caloriesPct: Int?
    let proteinPct: Int?
    let fatPct: Int?
    let carbsPct: Int?
    let waterPct: Int?
}
