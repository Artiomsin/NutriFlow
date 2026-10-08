import Foundation
import Observation

@Observable
@MainActor
final class GoalsViewModel {
    var state: GoalsState = .idle
    var personalizationState: PersonalizationState?
    var personalizationError: AppError?
    var saveError: AppError?
    var historyError: AppError?
    var isProcessingPersonalization = false
    
    @ObservationIgnored private let service: GoalsServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let cacheService: CacheService?
    @ObservationIgnored private let progressRefreshState: ProgressRefreshState?
    @ObservationIgnored private var goalLoadTask: Task<Void, Never>?
    @ObservationIgnored private var goalLoadGeneration = 0

    init(coordinator: AppCoordinator, service: GoalsServiceProtocol, cacheService: CacheService? = nil, progressRefreshState: ProgressRefreshState? = nil) {
        print("GoalsViewModel init")
        self.coordinator = coordinator
        self.service = service
        self.cacheService = cacheService
        self.progressRefreshState = progressRefreshState
    }

    deinit { print("GoalsViewModel deinit") }

    func loadGoals(forceRefresh: Bool = false) async {
        if !forceRefresh, let goalLoadTask {
            await goalLoadTask.value
            return
        }

        if forceRefresh {
            await cacheService?.remove("goals")
        }

        goalLoadGeneration &+= 1
        let generation = goalLoadGeneration

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performLoadGoals(generation: generation)
        }

        goalLoadTask = task
        await task.value

        if generation == goalLoadGeneration {
            goalLoadTask = nil
        }
    }

    private func performLoadGoals(generation: Int) async {
        if let cached: UserGoals = try? await cacheService?.get("goals") {
            guard generation == goalLoadGeneration else { return }
            state = .loaded(cached)
            return
        }

        guard generation == goalLoadGeneration else { return }

        if case .loaded = state {
        } else {
            state = .loading
        }

        do {
            #if DEBUG
            print("[Network] GoalsVM loadGoals")
            #endif

            let goals = try await service.getGoals()

            guard generation == goalLoadGeneration else { return }

            try? await cacheService?.set("goals", goals, ttl: 1800)
            state = .loaded(goals)
        } catch {
            guard generation == goalLoadGeneration else { return }

            let mapped = ErrorMapper.map(error)
            routeAuth(mapped)

            if mapped == .cancelled {
                return
            }

            if let cached: UserGoals = try? await cacheService?.get(
                "goals",
                ignoreTTL: true
            ) {
                state = .loaded(cached)
            } else if case .loaded = state {
                // Оставляем уже показанные данные при временной ошибке.
            } else {
                state = .error(mapped)
            }
        }
    }

    private func routeAuth(_ appError: AppError) {
        if appError == .unauthorized {
            coordinator?.goToAuth()
        }
    }

    func retryGoals() {
        Task { await loadGoals(forceRefresh: true) }
    }

    func retryPersonalization() {
        personalizationError = nil
        Task { await loadPersonalization() }
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
    
    func loadPersonalization(forceNetwork: Bool = false) async {
        if !forceNetwork,
           let cached: PersonalizationState = try? await cacheService?.get("goals_personalization") {
            personalizationState = cached
            personalizationError = nil
            return
        }
        do {
            let state = try await service.getPersonalizationState()
            try? await cacheService?.set("goals_personalization", state, ttl: 300)
            personalizationState = state
            personalizationError = nil
        } catch {
            if let cached: PersonalizationState = try? await cacheService?.get("goals_personalization", ignoreTTL: true) {
                personalizationState = cached
                return
            }
            let mapped = ErrorMapper.map(error)
            routeAuth(mapped)
            personalizationError = mapped == .cancelled ? nil : mapped
        }
    }

    @discardableResult
    func requestPersonalization() async -> PersonalizeResult? {
        guard !isProcessingPersonalization else { return nil }
        isProcessingPersonalization = true
        personalizationError = nil
        defer { isProcessingPersonalization = false }

        do {
            let result = try await service.personalizeGoals()
            await cacheService?.remove("goals_personalization")
            switch result {
            case .created(let rec), .pendingExists(let rec):
                personalizationState = PersonalizationState(pending: rec, personalizationDue: false, nextAvailableAt: nil)
            case .notDue(_, let nextAvailableAt):
                personalizationState = PersonalizationState(pending: nil, personalizationDue: false, nextAvailableAt: nextAvailableAt)
            case .insufficientData:
                personalizationState = PersonalizationState(pending: nil, personalizationDue: true, nextAvailableAt: nil)
            }
            personalizationError = nil
            return result
        } catch {
            let mapped = ErrorMapper.map(error)
            routeAuth(mapped)
            personalizationError = mapped == .cancelled ? nil : mapped
            return nil
        }
    }
    
    @discardableResult
    func acceptRecommendation(_ recommendation: GoalRecommendation) async -> Bool {
        guard !isProcessingPersonalization else { return false }
        isProcessingPersonalization = true
        personalizationError = nil
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
            await cacheService?.remove("goals_personalization")
            await cacheService?.remove("goals_history")
            await loadPersonalization(forceNetwork: true)
            await cacheService?.remove("summary_today")
            await cacheService?.removeByPrefix("chart_summaries")
            await cacheService?.removeByPrefix("analytics_")
            progressRefreshState?.invalidate()
            return true
        } catch {
            let mapped = ErrorMapper.map(error)
            routeAuth(mapped)
            if mapped == .notFound {
                await removeStaleRecommendation()
                return false
            }
            personalizationError = mapped == .cancelled ? nil : mapped
            return false
        }
    }


    
    @discardableResult
    func dismissRecommendation(_ recommendation: GoalRecommendation) async -> Bool {
        guard !isProcessingPersonalization else { return false }
        isProcessingPersonalization = true
        personalizationError = nil
        defer { isProcessingPersonalization = false }

        do {
            _ = try await service.dismissRecommendation(id: recommendation.id)
            await cacheService?.remove("goals_personalization")
            await loadPersonalization(forceNetwork: true)
            return true
        } catch {
            let mapped = ErrorMapper.map(error)
            routeAuth(mapped)
            if mapped == .notFound {
                await removeStaleRecommendation()
                return false
            }
            personalizationError = mapped == .cancelled ? nil : mapped
            return false
        }
    }

    private func removeStaleRecommendation() async {
        personalizationState = nil
        personalizationError = nil
        await cacheService?.remove("goals_personalization")
        await loadPersonalization(forceNetwork: true)
    }

    func loadGoalHistory() async -> [GoalHistoryEntry] {
        historyError = nil
        if let cached: [GoalHistoryEntry] = try? await cacheService?.get("goals_history") {
            return cached
        }
        do {
            let entries = try await service.getGoalHistory()
            try? await cacheService?.set("goals_history", entries, ttl: 300)
            return entries
        } catch {
            if let cached: [GoalHistoryEntry] = try? await cacheService?.get("goals_history", ignoreTTL: true) {
                return cached
            }
            let mapped = ErrorMapper.map(error)
            routeAuth(mapped)
            historyError = mapped == .cancelled ? nil : mapped
            return []
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
        saveError = nil
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
        } catch {
            let mapped = ErrorMapper.map(error)
            routeAuth(mapped)
            saveError = mapped == .cancelled ? nil : mapped
            return false
        }
    
    }

    @discardableResult
    func resetGoalsToAutomatic() async -> Bool {
        saveError = nil
        do {
            let updated = try await service.resetGoalsToAutomatic()
            state = .loaded(updated)
            try? await cacheService?.set("goals", updated, ttl: 1800)
            await cacheService?.remove("goals_history")
            await cacheService?.remove("summary_today")
            await cacheService?.removeByPrefix("chart_summaries")
            await cacheService?.removeByPrefix("analytics_")
            progressRefreshState?.invalidate()
            return true
        } catch {
            let mapped = ErrorMapper.map(error)
            routeAuth(mapped)
            saveError = mapped == .cancelled ? nil : mapped
            return false
        }
    }

    
}
