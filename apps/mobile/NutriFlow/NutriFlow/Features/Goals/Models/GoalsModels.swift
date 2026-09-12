import Foundation

struct UserGoals: Codable, Sendable {
    let id: String?
    let userId: String?
    let dailyCaloriesGoal: Int?
    let dailyProteinGoal: Int?
    let dailyFatGoal: Int?
    let dailyCarbsGoal: Int?
    let dailyWaterGoal: Int?
    
    let dailyStepsGoal: Int?
    let dailyActiveCaloriesGoal: Int?
    
    let weeklyWorkoutsGoal: Int?
    let weeklyWorkoutMinutesGoal: Int?
    
    let nightlySleepMinMinutes: Int?
    let nightlySleepMaxMinutes: Int?
    
    let source: String?
    let createdAt: String?
    let updatedAt: String?
}

struct UpdateGoalsRequest: Codable, Sendable {
    let dailyCaloriesGoal: Int?
    let dailyProteinGoal: Int?
    let dailyFatGoal: Int?
    let dailyCarbsGoal: Int?
    let dailyWaterGoal: Int?
    let dailyStepsGoal: Int?
    let dailyActiveCaloriesGoal: Int?
    let weeklyWorkoutsGoal: Int?
    let weeklyWorkoutMinutesGoal: Int?
    let nightlySleepMinMinutes: Int?
    let nightlySleepMaxMinutes: Int?
}
