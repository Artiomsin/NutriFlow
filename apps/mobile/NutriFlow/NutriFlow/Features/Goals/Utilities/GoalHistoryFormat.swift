import Foundation


enum GoalHistoryFormat {
    private static let metrics = [
        "dailyCaloriesGoal",
        "dailyProteinGoal",
        "dailyFatGoal",
        "dailyCarbsGoal",
        "dailyWaterGoal",
        "dailyStepsGoal",
        "dailyActiveCaloriesGoal",
        "weeklyWorkoutsGoal",
        "weeklyWorkoutMinutesGoal",
        "nightlySleepMinMinutes",
        "nightlySleepMaxMinutes"
    ]

    static func order(of metric: String) -> Int {
        metrics.firstIndex(of: metric) ?? metrics.count
    }

    static func metricLabel(_ metric: String) -> String {
        switch metric {
        case "dailyCaloriesGoal": return "Calories"
        case "dailyProteinGoal": return "Protein"
        case "dailyFatGoal": return "Fat"
        case "dailyCarbsGoal": return "Carbs"
        case "dailyWaterGoal": return "Water"
        case "dailyStepsGoal": return "Steps"
        case "dailyActiveCaloriesGoal": return "Active calories"
        case "weeklyWorkoutsGoal": return "Workouts / week"
        case "weeklyWorkoutMinutesGoal": return "Workout minutes / week"
        case "nightlySleepMinMinutes": return "Sleep min / night"
        case "nightlySleepMaxMinutes": return "Sleep max / night"
        default: return metric
        }
    }

    static func sourceLabel(_ source: String) -> String {
        switch source.lowercased() {
        case "initial": return "Automatic"
        case "user": return "Manual"
        case "personalized": return "Personalized"
        default: return "Auto"
        }
    }

    static func reasonLabel(_ reason: String?) -> String? {
        switch reason {
        case "recommendation_accepted":
            return "Updated from a personalized recommendation"
        case "user_edit":
            return "Updated manually"
        case "manual_reset_to_automatic":
            return "Switched to automatic goals"
        case "profile_recalculation":
            return "Recalculated from profile and weight"
        case "personalized_profile_recalculation":
            return "Recalculated while keeping recommendation adjustments"
        case "initial_calculation":
            return "Initial automatic calculation"
        case nil, "":
            return nil
        default:
            return reason
        }
    }

    static func value(_ metric: String, _ value: Double?) -> String {
        guard let value else { return "—" }
        let number = value.formatted(.number.precision(.fractionLength(0...1)))

        switch metric {
        case "dailyProteinGoal", "dailyFatGoal", "dailyCarbsGoal":
            return "\(number) g"
        case "dailyWaterGoal":
            return "\(number) ml"
        case "weeklyWorkoutMinutesGoal",
             "nightlySleepMinMinutes",
             "nightlySleepMaxMinutes":
            return "\(number) min"
        default:
            return number
        }
    }
}
