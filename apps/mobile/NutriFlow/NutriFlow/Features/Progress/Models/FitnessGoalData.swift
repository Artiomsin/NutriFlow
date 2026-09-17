import Foundation

enum FitnessGoalKind {
    case steps
    case activeCalories
    case sleep
    case workouts
    case workoutMinutes
}

struct FitnessGoalRowData {
    let kind: FitnessGoalKind
    let goal: Int
    let value: Int
    let unit: String
    let show: Bool
    let valueText: String?

    var percent: Int {
        guard goal > 0 else { return 0 }
        return Int((Double(value) / Double(goal) * 100).rounded())
    }
}