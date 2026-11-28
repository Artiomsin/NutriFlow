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

    static func sourceLabel(_ source: String, reason: String? = nil) -> String {
        // Older versions stored suggestion applies with `initial` source.
        // Treat them as manual so historical events stay correctly classified.
        if let reason, isManualReason(reason) {
            return "Manual"
        }

        switch source.lowercased() {
        case "initial": return "Automatic"
        case "user": return "Manual"
        case "personalized": return "Personalized"
        default: return "Auto"
        }
    }

    static func reasonLabel(_ reason: String?) -> String? {
        guard let reason, !reason.isEmpty else { return nil }

        if reason.hasPrefix("new_cycle_") {
            return "Started a new goal cycle"
        }

        switch reason {
        case "recommendation_accepted":
            return "Updated from a personalized recommendation"
        case "user_edit":
            return "Updated manually"
        case "suggestion_applied":
            return "Applied suggested values"
        case "suggestion_partially_applied":
            return "Applied selected suggested values"
        case "manual_reset_to_automatic":
            return "Switched to automatic goals"
        case "profile_recalculation", "profile_changed", "weight_changed":
            return "Recalculated from profile and weight"
        case "personalized_profile_recalculation":
            return "Recalculated while keeping recommendation adjustments"
        case "progress_adjustment_applied":
            return "Applied a progress recommendation"
        case "initial_calculation":
            return "Initial automatic calculation"
        default:
            return reason
        }
    }

    private static func isManualReason(_ reason: String) -> Bool {
        reason == "user_edit"
            || reason == "suggestion_applied"
            || reason == "suggestion_partially_applied"
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
