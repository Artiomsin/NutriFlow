import Foundation
import Observation

@Observable
@MainActor
final class GoalsViewModel {
    var state: GoalsState = .idle

    @ObservationIgnored private let service: GoalsServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let cacheService: CacheService?

    init(coordinator: AppCoordinator, service: GoalsServiceProtocol, cacheService: CacheService? = nil) {
        print("GoalsViewModel init")
        self.coordinator = coordinator
        self.service = service
        self.cacheService = cacheService
    }

    deinit { print("GoalsViewModel deinit") }

    func loadGoals() async {
        if let cached: UserGoals = try? await cacheService?.get("goals") {
            state = .loaded(cached)
            return
        }

        if case .loaded = state {} else { state = .loading }
        do {
            #if DEBUG
            print("[Network] GoalsVM loadGoals")
            #endif
            let goals = try await service.getGoals()
            try? await cacheService?.set("goals", goals, ttl: 1800)
            state = .loaded(goals)
        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator?.goToAuth()
            }
            if let cached: UserGoals = try? await cacheService?.get("goals", ignoreTTL: true) {
                state = .loaded(cached)
            } else if case .loaded = state {} else {
                state = .error(error)
            }
        } catch {
            if let cached: UserGoals = try? await cacheService?.get("goals", ignoreTTL: true) {
                state = .loaded(cached)
            } else if case .loaded = state {} else {
                state = .error(error)
            }
        }
    }

    func fitnessGoalRows(
        avgSteps: Double,
        avgActiveCalories: Double,
        sleepNightsInRange: Int,
        sleepTotalNights: Int,
        workoutsDone: Int,
        workoutMinutes: Int,
        daysCount: Int
    ) -> [FitnessGoalRowData] {
        guard case .loaded(let goals) = state else { return [] }
        let stepsGoal = goals.dailyStepsGoal ?? 0
        let activeGoal = goals.dailyActiveCaloriesGoal ?? 0
        let sleepMin = goals.nightlySleepMinMinutes ?? 0
        let sleepMax = goals.nightlySleepMaxMinutes ?? 0
        let workoutsGoal = scaledGoal(goals.weeklyWorkoutsGoal ?? 0, days: daysCount)
        let workoutMinutesGoal = scaledGoal(goals.weeklyWorkoutMinutesGoal ?? 0, days: daysCount)

        return [
            FitnessGoalRowData(
                kind: .steps,
                goal: stepsGoal,
                value: Int(avgSteps),
                unit: "",
                show: stepsGoal > 0,
                valueText: nil
            ),
            FitnessGoalRowData(
                kind: .activeCalories,
                goal: activeGoal,
                value: Int(avgActiveCalories),
                unit: UnitConversion.formatEnergyUnit(preferred: PreferencesStore.shared.preferredUnits),
                show: activeGoal > 0,
                valueText: nil
            ),
            FitnessGoalRowData(
                kind: .sleep,
                goal: sleepTotalNights,
                value: sleepNightsInRange,
                unit: "nights",
                show: sleepMin > 0 && sleepMax > 0 && sleepTotalNights > 0,
                valueText: "\(sleepNightsInRange)/\(sleepTotalNights)"
            ),
            FitnessGoalRowData(
                kind: .workouts,
                goal: workoutsGoal,
                value: workoutsDone,
                unit: "",
                show: workoutsGoal > 0 && workoutsDone > 0,
                valueText: "\(workoutsDone)/\(workoutsGoal)"
            ),
            FitnessGoalRowData(
                kind: .workoutMinutes,
                goal: workoutMinutesGoal,
                value: workoutMinutes,
                unit: "min",
                show: workoutMinutesGoal > 0 && workoutMinutes > 0,
                valueText: "\(workoutMinutes)/\(workoutMinutesGoal)"
            )
        ]
    }

    private func scaledGoal(_ weeklyGoal: Int, days: Int) -> Int {
        guard weeklyGoal > 0 else { return 0 }
        guard days > 0 else { return weeklyGoal }
        return Int((Double(weeklyGoal) * Double(days) / 7.0).rounded())
    }
}
