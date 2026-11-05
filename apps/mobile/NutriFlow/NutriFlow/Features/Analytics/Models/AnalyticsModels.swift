import Foundation

enum TrendType: String, Codable, Sendable {
    case increasing
    case decreasing
    case stable
    case insufficientData = "insufficient_data"
}

struct AnalyticsResponse: Codable, Sendable {
    let period: String
    let fromDate: String
    let toDate: String

    let averageCalories: Double
    let averageProtein: Double
    let averageFat: Double
    let averageCarbs: Double
    let averageWater: Int

    let goalCalories: Double?
    let goalCaloriesPct: Int?
    let goalProtein: Double?
    let goalProteinPct: Int?
    let goalFat: Double?
    let goalFatPct: Int?
    let goalCarbs: Double?
    let goalCarbsPct: Int?
    let goalWater: Int?
    let goalWaterPct: Int?

    let avgSteps: Int?
    let avgActiveCalories: Int?
    let goalSteps: Int?
    let goalStepsPct: Int?
    let goalActiveCalories: Int?
    let goalActiveCaloriesPct: Int?
    let sleepTotalNights: Int?
    let sleepNightsInRange: Int?
    let workoutsDone: Int?
    let workoutMinutes: Int?

    let daysTracked: Int
    let totalDays: Int

    let streak: Int
    let streakStart: String?
    let trend: TrendType

    let daily: [AnalyticsDay]
}

struct AnalyticsDay: Codable, Sendable {
    let date: String
    let calories: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let water: Int

    let caloriesPct: Int?
    let proteinPct: Int?
    let fatPct: Int?
    let carbsPct: Int?
    let waterPct: Int?
}
