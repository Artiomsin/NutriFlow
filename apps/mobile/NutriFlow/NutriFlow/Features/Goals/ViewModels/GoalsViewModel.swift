import Foundation
import Observation

@Observable
@MainActor
final class GoalsViewModel {
    var state: GoalsState = .idle
    var personalizationState: PersonalizationState?
    var isProcessingPersonalization = false
    
    @ObservationIgnored private let service: GoalsServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let cacheService: CacheService?
    @ObservationIgnored private let progressRefreshState: ProgressRefreshState?

    init(coordinator: AppCoordinator, service: GoalsServiceProtocol, cacheService: CacheService? = nil, progressRefreshState: ProgressRefreshState? = nil) {
        print("GoalsViewModel init")
        self.coordinator = coordinator
        self.service = service
        self.cacheService = cacheService
        self.progressRefreshState = progressRefreshState
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
    
    func loadPersonalization() async {
        if let cached: PersonalizationState = try? await cacheService?.get("goals_personalization") {
            personalizationState = cached
            return
        }
        do {
            let state = try await service.getPersonalizationState()
            try? await cacheService?.set("goals_personalization", state, ttl: 300)
            personalizationState = state
        } catch let error as APIError {
            if case .unauthorized = error { coordinator?.goToAuth() }
            if let cached: PersonalizationState = try? await cacheService?.get("goals_personalization", ignoreTTL: true) {
                personalizationState = cached
            }
        } catch {
            if let cached: PersonalizationState = try? await cacheService?.get("goals_personalization", ignoreTTL: true) {
                personalizationState = cached
            }
        }
    }

    @discardableResult
    func requestPersonalization() async -> PersonalizeResult? {
        guard !isProcessingPersonalization else { return nil }
        isProcessingPersonalization = true
        defer { isProcessingPersonalization = false }

        do {
            let result = try await service.personalizeGoals()
            await cacheService?.remove("goals_personalization")
            switch result {
            case .created(let rec), .pendingExists(let rec):
                personalizationState = PersonalizationState(pending: rec, personalizationDue: false)
            case .notDue:
                personalizationState = PersonalizationState(
                    pending: personalizationState?.pending,
                    personalizationDue: false
                )
            case .insufficientData:
                personalizationState = PersonalizationState(pending: nil, personalizationDue: true)
            }
            return result
        } catch let error as APIError {
            if case .unauthorized = error { coordinator?.goToAuth() }
            return nil
        } catch {
            return nil
        }
    }
    
    @discardableResult
    func acceptRecommendation(_ recommendation: GoalRecommendation) async -> Bool {
        guard !isProcessingPersonalization else { return false }
        isProcessingPersonalization = true
        defer { isProcessingPersonalization = false }

        do {
            let metrics = try await service.acceptRecommendation(id: recommendation.id)
            if case .loaded(let goals) = state {
                let updated = goals.applying(metrics, source: "personalized")
                state = .loaded(updated)
                try? await cacheService?.set("goals", updated, ttl: 1800)
            } else {
                await cacheService?.remove("goals")
                await loadGoals()
            }
            personalizationState = PersonalizationState(pending: nil, personalizationDue: false)
            await cacheService?.remove("goals_personalization")
            await cacheService?.remove("summary_today")
            await cacheService?.removeByPrefix("chart_summaries")
            await cacheService?.removeByPrefix("analytics_")
            progressRefreshState?.invalidate()
            return true
        } catch let error as APIError {
            if case .unauthorized = error { coordinator?.goToAuth() }
            return false
        } catch {
            return false
        }
    }
    
    @discardableResult
    func dismissRecommendation(_ recommendation: GoalRecommendation) async -> Bool {
        guard !isProcessingPersonalization else { return false }
        isProcessingPersonalization = true
        defer { isProcessingPersonalization = false }

        do {
            _ = try await service.dismissRecommendation(id: recommendation.id)
            personalizationState = PersonalizationState(pending: nil, personalizationDue: false)
            await cacheService?.remove("goals_personalization")
            return true
        } catch let error as APIError {
            if case .unauthorized = error { coordinator?.goToAuth() }
            return false
        } catch {
            return false
        }
    }

    func loadGoalHistory() async -> [GoalHistoryEntry] {
        if let cached: [GoalHistoryEntry] = try? await cacheService?.get("goals_history") {
            return cached
        }
        do {
            let entries = try await service.getGoalHistory()
            try? await cacheService?.set("goals_history", entries, ttl: 300)
            return entries
        } catch let error as APIError {
            if case .unauthorized = error { coordinator?.goToAuth() }
            return (try? await cacheService?.get("goals_history", ignoreTTL: true)) ?? []
        } catch {
            return (try? await cacheService?.get("goals_history", ignoreTTL: true)) ?? []
        }
    }

    @discardableResult
    func updateGoals(
        calories: Int?,
        protein: Int?,
        fat: Int?,
        carbs: Int?,
        water: Int?,
        steps: Int?,
        activeCalories: Int?,
        workouts: Int?,
        workoutMinutes: Int?,
        sleepMinMinutes: Int?,
        sleepMaxMinutes: Int?
    ) async -> Bool {
        do {
            let updated = try await service.updateGoals(
                calories: calories,
                protein: protein,
                fat: fat,
                carbs: carbs,
                water: water,
                steps: steps,
                activeCalories: activeCalories,
                workouts: workouts,
                workoutMinutes: workoutMinutes,
                sleepMinMinutes: sleepMinMinutes,
                sleepMaxMinutes: sleepMaxMinutes
            )
            state = .loaded(updated)
            try? await cacheService?.set("goals", updated, ttl: 1800)
            await cacheService?.remove("goals_history")
            await cacheService?.remove("summary_today")
            await cacheService?.removeByPrefix("chart_summaries")
            await cacheService?.removeByPrefix("analytics_")
            progressRefreshState?.invalidate()
            return true
        } catch let error as APIError {
            if case .unauthorized = error { coordinator?.goToAuth() }
            return false
        } catch {
            return false
        }
    }

    
}
