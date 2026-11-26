import Foundation
import Observation

@Observable
@MainActor
final class GoalsViewModel {
    var state: GoalsState = .idle
    var personalizationState: PersonalizationState?
    var personalizationError: AppError?
    var saveError: AppError?
    var fieldErrors = FormFieldErrors()
    var historyError: AppError?
    var preview: GoalsPreview?
    var previewError: AppError?
    var isLoadingPreview = false
    var isUpdatingGoals = false
    var isProcessingPersonalization = false
    /// Goals active at the end of the selected Progress period.
    var periodGoals: UserGoals?
    
    @ObservationIgnored private let service: GoalsServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let cacheService: CacheService?
    @ObservationIgnored private let progressRefreshState: ProgressRefreshState?
    @ObservationIgnored private var goalLoadTask: Task<Void, Never>?
    @ObservationIgnored private var goalLoadGeneration = 0
    @ObservationIgnored private var periodGoalsLoadTask: Task<Void, Never>?
    @ObservationIgnored private var periodGoalsLoadKey: String?
    @ObservationIgnored private var periodGoalsLoadGeneration = 0
    @ObservationIgnored private var loadedPeriodGoalsKey: String?
    @ObservationIgnored private var previewLoadGeneration = 0

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
            // Preview is a companion to the current goal state, so it is refreshed
            // whenever callers load goals rather than waiting for the future UI.
            await loadGoalsPreview(forceRefresh: forceRefresh)
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
                // Keep the already shown data on a temporary error.
            } else {
                state = .error(mapped)
            }
        }
    }

    func loadGoalsPreview(forceRefresh: Bool = false) async {
        let cacheKey = "goals_preview"
        previewLoadGeneration &+= 1
        let generation = previewLoadGeneration

        if forceRefresh {
            await cacheService?.remove(cacheKey)
        } else if let cached: GoalsPreview = try? await cacheService?.get(cacheKey) {
            preview = cached
            previewError = nil
            return
        }

        isLoadingPreview = true
        defer {
            if generation == previewLoadGeneration {
                isLoadingPreview = false
            }
        }

        do {
            let loaded = try await service.getGoalsPreview()
            guard generation == previewLoadGeneration else { return }
            preview = loaded
            previewError = nil
            try? await cacheService?.set(cacheKey, loaded, ttl: 300)
        } catch is CancellationError {
            return
        } catch {
            guard generation == previewLoadGeneration else { return }
            let mapped = ErrorMapper.map(error)
            routeAuth(mapped)
            if let stale: GoalsPreview = try? await cacheService?.get(cacheKey, ignoreTTL: true) {
                preview = stale
                previewError = nil
            } else {
                previewError = mapped
            }
        }
    }

    func retryGoalsPreview() {
        Task { await loadGoalsPreview(forceRefresh: true) }
    }

    private func routeAuth(_ appError: AppError) {
        if appError == .unauthorized {
            coordinator?.goToAuth()
        }
    }

    func retryGoals() {
        Task { await loadGoals(forceRefresh: true) }
    }

    func clearFieldError(_ field: String) {
        fieldErrors.clear(field)
        saveError = nil
    }

    func retryPersonalization() {
        personalizationError = nil
        Task { await loadPersonalization() }
    }

    /// Loads the goal version that was active at the end of the selected
    /// period, so historical rings are not compared with a newer goal.
    func loadPeriodGoals(endingOn date: Date, forceRefresh: Bool = false) async {
        let dateString = AppDate.dateOnlyFormatter().string(from: date)
        let cacheKey = "period_goals_\(dateString)"

        if !forceRefresh, loadedPeriodGoalsKey == cacheKey {
            return
        }
        if !forceRefresh,
           periodGoalsLoadKey == cacheKey,
           let periodGoalsLoadTask {
            await periodGoalsLoadTask.value
            return
        }

        if forceRefresh {
            await cacheService?.remove(cacheKey)
            periodGoalsLoadTask?.cancel()
        }

        periodGoalsLoadGeneration &+= 1
        let generation = periodGoalsLoadGeneration
        periodGoalsLoadKey = cacheKey
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performLoadPeriodGoals(
                dateString: dateString,
                cacheKey: cacheKey,
                generation: generation
            )
        }
        periodGoalsLoadTask = task
        await task.value

        if generation == periodGoalsLoadGeneration {
            periodGoalsLoadTask = nil
            periodGoalsLoadKey = nil
        }
    }

    private func performLoadPeriodGoals(
        dateString: String,
        cacheKey: String,
        generation: Int
    ) async {
        if let cached: UserGoals = try? await cacheService?.get(cacheKey) {
            guard generation == periodGoalsLoadGeneration else { return }
            periodGoals = cached
            loadedPeriodGoalsKey = cacheKey
            return
        }

        do {
            #if DEBUG
            print("[Network] GoalsVM loadPeriodGoals \(dateString)")
            #endif
            let loaded = try await service.getGoals(date: dateString)
            guard !Task.isCancelled, generation == periodGoalsLoadGeneration else { return }
            try? await cacheService?.set(cacheKey, loaded, ttl: 1_800)
            periodGoals = loaded
            loadedPeriodGoalsKey = cacheKey
        } catch is CancellationError {
            return
        } catch {
            guard generation == periodGoalsLoadGeneration else { return }
            let appError = ErrorMapper.map(error)
            routeAuth(appError)

            if let stale: UserGoals = try? await cacheService?.get(cacheKey, ignoreTTL: true) {
                periodGoals = stale
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
        let goals: UserGoals
        if let periodGoals {
            goals = periodGoals
        } else if case .loaded(let current) = state {
            goals = current
        } else {
            return []
        }
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
            case .collectData, .noChange:
                await loadPersonalization(forceNetwork: true)
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
        guard !isProcessingPersonalization, !isUpdatingGoals else { return false }
        isProcessingPersonalization = true
        isUpdatingGoals = true
        personalizationError = nil
        defer {
            isProcessingPersonalization = false
            isUpdatingGoals = false
        }

        do {
            let updated = try await service.acceptRecommendation(id: recommendation.id)
            await applyUpdatedGoals(updated)
            await cacheService?.remove("profile")
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

    func loadGoalHistory(
        limit: Int = 20,
        cursor: String? = nil,
        forceNetwork: Bool = false
    ) async -> GoalHistoryPage? {
        historyError = nil
        let isFirstPage = cursor == nil

        if isFirstPage,
           !forceNetwork,
           let cached: GoalHistoryPage = try? await cacheService?.get("goals_history") {
            return cached
        }

        do {
            let page = try await service.getGoalHistory(
                limit: limit,
                cursor: cursor
            )
            if isFirstPage {
                try? await cacheService?.set("goals_history", page, ttl: 600)
            }
            return page
        } catch {
            if isFirstPage,
               let cached: GoalHistoryPage = try? await cacheService?.get(
                   "goals_history",
                   ignoreTTL: true
               ) {
                return cached
            }
            let mapped = ErrorMapper.map(error)
            routeAuth(mapped)
            historyError = mapped == .cancelled ? nil : mapped
            return nil
        }
    }

    @discardableResult
    func updateGoals(
        calories: Double?,
        protein: Double?,
        fat: Double?,
        carbs: Double?,
        water: Int?,
        steps: Int?,
        activeCalories: Int?,
        workouts: Int?,
        workoutMinutes: Int?,
        sleepMinMinutes: Int?,
        sleepMaxMinutes: Int?
    ) async -> Bool {
        guard !isUpdatingGoals else { return false }
        isUpdatingGoals = true
        defer { isUpdatingGoals = false }

        saveError = nil
        fieldErrors.removeAll()
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
            await applyUpdatedGoals(updated)
            return true
        } catch {
            switch ErrorHandler.handle(
                error,
                supportedFields: [
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
            ) {
            case .fieldErrors(let errors):
                fieldErrors = errors
            case .general(let appError):
                routeAuth(appError)
                saveError = appError == .cancelled ? nil : appError
            }
            return false
        }
    }

    @discardableResult
    func resetGoalsToAutomatic() async -> Bool {
        guard !isUpdatingGoals else { return false }
        isUpdatingGoals = true
        defer { isUpdatingGoals = false }

        saveError = nil
        fieldErrors.removeAll()
        do {
            let updated = try await service.resetGoalsToAutomatic()
            await applyUpdatedGoals(updated)
            return true
        } catch {
            let mapped = ErrorMapper.map(error)
            routeAuth(mapped)
            saveError = mapped == .cancelled ? nil : mapped
            return false
        }
    }

    @discardableResult
    func applySuggestedGoals(metrics: [GoalMetricKey]? = nil) async -> Bool {
        guard !isUpdatingGoals else { return false }
        isUpdatingGoals = true
        defer { isUpdatingGoals = false }

        saveError = nil
        fieldErrors.removeAll()
        do {
            let updated = try await service.applySuggestion(metrics: metrics)
            await applyUpdatedGoals(updated)
            return true
        } catch {
            handleGoalMutationError(error)
            return false
        }
    }

    @discardableResult
    func dismissGoalSuggestion() async -> Bool {
        guard !isUpdatingGoals else { return false }
        isUpdatingGoals = true
        defer { isUpdatingGoals = false }

        saveError = nil
        fieldErrors.removeAll()
        do {
            let updated = try await service.dismissSuggestion()
            await applyUpdatedGoals(updated)
            return true
        } catch {
            handleGoalMutationError(error)
            return false
        }
    }

    @discardableResult
    func clearManualOverrides() async -> Bool {
        guard !isUpdatingGoals else { return false }
        isUpdatingGoals = true
        defer { isUpdatingGoals = false }

        saveError = nil
        fieldErrors.removeAll()
        do {
            let updated = try await service.clearManualOverrides()
            await applyUpdatedGoals(updated)
            return true
        } catch {
            handleGoalMutationError(error)
            return false
        }
    }

    @discardableResult
    func clearManualOverride(metric: GoalMetricKey) async -> Bool {
        guard !isUpdatingGoals else { return false }
        isUpdatingGoals = true
        defer { isUpdatingGoals = false }

        saveError = nil
        fieldErrors.removeAll()
        do {
            let updated = try await service.clearManualOverride(metric: metric)
            await applyUpdatedGoals(updated)
            return true
        } catch {
            handleGoalMutationError(error)
            return false
        }
    }

    @discardableResult
    func applyProgressAdjustment(
        days: Int,
        metrics: GoalMetrics?
    ) async -> Bool {
        guard !isUpdatingGoals else { return false }
        isUpdatingGoals = true
        defer { isUpdatingGoals = false }

        saveError = nil
        fieldErrors.removeAll()
        do {
            let updated = try await service.applyProgressAdjustment(
                days: days,
                metrics: metrics
            )
            await applyUpdatedGoals(updated)
            return true
        } catch {
            handleGoalMutationError(error)
            return false
        }
    }

    @discardableResult
    func startNewCycle(_ request: NewGoalCycleRequest) async -> Bool {
        guard !isUpdatingGoals else { return false }
        isUpdatingGoals = true
        defer { isUpdatingGoals = false }

        saveError = nil
        fieldErrors.removeAll()
        do {
            let updated = try await service.startNewCycle(request)
            await applyUpdatedGoals(updated)
            await cacheService?.remove("profile")
            return true
        } catch {
            handleGoalMutationError(error)
            return false
        }
    }

    private func applyUpdatedGoals(_ updated: UserGoals) async {
        state = .loaded(updated)
        try? await cacheService?.set("goals", updated, ttl: 1_800)
        await cacheService?.remove("goals_history")
        await cacheService?.remove("goals_personalization")
        await cacheService?.remove("goals_preview")
        await cacheService?.removeByPrefix("goals_progress_")
        await invalidatePeriodGoalsCache()
        await cacheService?.remove("summary_today")
        await cacheService?.removeByPrefix("chart_summaries")
        await cacheService?.removeByPrefix("analytics_")
        progressRefreshState?.invalidateGoals()
        await loadGoalsPreview(forceRefresh: true)
        await loadPersonalization(forceNetwork: true)
    }

    private func handleGoalMutationError(_ error: Error) {
        switch ErrorHandler.handle(
            error,
            supportedFields: [
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
        ) {
        case .fieldErrors(let errors):
            fieldErrors = errors
            saveError = nil
        case .general(let appError):
            routeAuth(appError)
            saveError = appError == .cancelled ? nil : appError
        }
    }

    func invalidatePeriodGoalsCache() async {
        periodGoalsLoadGeneration &+= 1
        loadedPeriodGoalsKey = nil
        periodGoalsLoadKey = nil
        periodGoalsLoadTask?.cancel()
        periodGoalsLoadTask = nil
        periodGoals = nil
        await cacheService?.removeByPrefix("period_goals_")
    }
}
