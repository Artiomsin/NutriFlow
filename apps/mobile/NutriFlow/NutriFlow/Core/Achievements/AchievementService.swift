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
                title: "Дневная норма воды выполнена",
                body: "Вы выпили \(totalMl) мл из \(goalMl) мл. Отличная работа!"
            )
        ]
    }

    func checkSteps(_ steps: Int, goal: Int) -> [Achievement] {
        guard goal > 0, steps >= goal else { return [] }
        return [
            Achievement(
                id: dailyID("steps"),
                title: "Цель по шагам выполнена",
                body: "\(steps) шагов из \(goal). Так держать!"
            )
        ]
    }

    func checkActiveCalories(_ kcal: Int, goal: Int) -> [Achievement] {
        guard goal > 0, kcal >= goal else { return [] }
        return [
            Achievement(
                id: dailyID("active_calories"),
                title: "Норма активных калорий достигнута",
                body: "\(kcal) ккал из \(goal). Отличная активность!"
            )
        ]
    }

    func checkCalories(consumed: Int, goal: Int) -> [Achievement] {
        guard goal > 0, consumed >= goal else { return [] }

        return [
            Achievement(
                id: dailyID("nutrition"),
                title: "Цель по питанию выполнена",
                body: "\(consumed) ккал при дневной цели \(goal) ккал."
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
            title: "Недельная норма тренировок выполнена",
            body: "\(count) из \(goal) тренировок. Супер!"
        )]
    }

    func checkWorkoutMinutes(minutes: Int, goal: Int) -> [Achievement] {
        guard goal > 0, minutes >= goal else { return [] }
        return [Achievement(
            id: weeklyID("workout_minutes"),
            title: "Норма минут тренировок выполнена",
            body: "\(minutes) мин из \(goal) мин за неделю."
        )]
    }

    func checkSleep(minutes: Int, minGoal: Int, maxGoal: Int) -> [Achievement] {
        guard minGoal > 0, minutes >= minGoal else { return [] }
        return [Achievement(
            id: dailyID("sleep"),
            title: "Норма сна выполнена",
            body: "\(minutes / 60) ч \(minutes % 60) мин сна."
        )]
        
    }
}
