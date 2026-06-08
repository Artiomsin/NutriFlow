import Foundation

struct UserGoals: Codable {
    let id: String?
    let userId: String?
    let dailyCaloriesGoal: Int?
    let dailyProteinGoal: Int?
    let dailyFatGoal: Int?
    let dailyCarbsGoal: Int?
    let dailyWaterGoal: Int?
    let source: String?
    let createdAt: String?
    let updatedAt: String?
}

struct UpdateGoalsRequest: Codable {
    let dailyCaloriesGoal: Int?
    let dailyProteinGoal: Int?
    let dailyFatGoal: Int?
    let dailyCarbsGoal: Int?
    let dailyWaterGoal: Int?
}
