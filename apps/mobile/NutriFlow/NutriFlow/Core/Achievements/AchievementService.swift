import Foundation

struct AchievementService: Sendable {

    private static let calendar = Calendar(identifier: .gregorian)

    func dailyID(_ prefix: String, date: Date = .now) -> String {
        "\(prefix)_\(Achievement.dayFormatter.string(from: date))"
    }

    func checkWater(totalMl: Int, goalMl: Int) -> [Achievement] {
        guard goalMl > 0, totalMl >= goalMl else { return [] }
        return [
            Achievement(
                id: dailyID("water"),
                title: "Daily water goal reached",
                body: "You drank \(totalMl) ml of \(goalMl) ml. Great job!"
            )
        ]
    }

    func checkSteps(_ steps: Int, goal: Int) -> [Achievement] {
        guard goal > 0, steps >= goal else { return [] }
        return [
            Achievement(
                id: dailyID("steps"),
                title: "Daily step goal reached",
                body: "\(steps) of \(goal) steps. Keep it up!"
            )
        ]
    }

    func checkActiveCalories(_ kcal: Int, goal: Int) -> [Achievement] {
        guard goal > 0, kcal >= goal else { return [] }
        return [
            Achievement(
                id: dailyID("active_calories"),
                title: "Active calorie goal reached",
                body: "\(kcal) of \(goal) kcal. Great activity!"
            )
        ]
    }

    func checkCalories(consumed: Int, goal: Int) -> [Achievement] {
        guard goal > 0, consumed >= goal else { return [] }

        return [
            Achievement(
                id: dailyID("nutrition"),
                title: "Nutrition goal reached",
                body: "\(consumed) kcal with a daily goal of \(goal) kcal."
            )
        ]
    }
    
    
    func weeklyID(_ prefix: String, date: Date = .now) -> String {
        let year = Self.calendar.component(.yearForWeekOfYear, from: date)
        let week = Self.calendar.component(.weekOfYear, from: date)
        return "\(prefix)_\(year)-W\(week)"
    }
    
    func checkWorkouts(count: Int, goal: Int) -> [Achievement] {
        guard goal > 0, count >= goal else { return [] }
        return [Achievement(
            id: weeklyID("workouts"),
            title: "Weekly workout goal reached",
            body: "\(count) of \(goal) workouts. Awesome!"
        )]
    }

    func checkWorkoutMinutes(minutes: Int, goal: Int) -> [Achievement] {
        guard goal > 0, minutes >= goal else { return [] }
        return [Achievement(
            id: weeklyID("workout_minutes"),
            title: "Weekly workout minutes goal reached",
            body: "\(minutes) of \(goal) min this week."
        )]
    }

    func checkSleep(minutes: Int, minGoal: Int, maxGoal: Int) -> [Achievement] {
        guard minGoal > 0, minutes >= minGoal else { return [] }
        return [Achievement(
            id: dailyID("sleep"),
            title: "Sleep goal reached",
            body: "\(minutes / 60) h \(minutes % 60) min of sleep."
        )]
        
    }
}
