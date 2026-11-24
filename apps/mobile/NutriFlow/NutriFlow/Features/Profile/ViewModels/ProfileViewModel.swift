import Foundation
import Observation

@Observable
@MainActor
final class ProfileViewModel {
    
    var state: ProfileState = .loading
    
    var weight: String = ""
    var height: String = ""
    var age: String = ""
    
    var email: String = ""
    var firstName: String = ""
    var lastName: String = ""
    
    var gender: Gender?
    var goal: Goal?
    var activityLevel: ActivityLevel?
    var preferredUnits: PreferredUnits = .default

    // Goal-plan fields are kept separate from the general profile form.
    var targetWeight: String = ""
    var maintainWeightMin: String = ""
    var maintainWeightMax: String = ""
    var weeklyRateKg: String = ""
    var targetDate: String = ""
    var goalStartedAt: String?

    var saveError: AppError?
    var unitsError: AppError?
    var timeZoneError: AppError?
    var fieldErrors = FormFieldErrors()

    private var originalWeightKg: Double?
    private var originalWeightText: String?
    private var originalHeightCm: Int?
    private var originalTargetWeightKg: Double?
    private var originalMaintainWeightMinKg: Double?
    private var originalMaintainWeightMaxKg: Double?
    @ObservationIgnored private var lastSavedUnits: PreferredUnits = .default

    @ObservationIgnored private let authService: AuthServiceProtocol
    @ObservationIgnored private let profileService: ProfileServiceProtocol
    @ObservationIgnored private let userService: UserServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let cacheService: CacheService?
    @ObservationIgnored private let progressRefreshState: ProgressRefreshState?
    @ObservationIgnored private let activitySync: ActivitySyncProtocol?
    @ObservationIgnored private let analyticsTracker: AnalyticsTracking?
    @ObservationIgnored private let weightReminderScheduler: WeightReminderScheduling?
    @ObservationIgnored private let waterReminderScheduler: WaterReminderScheduling?
    @ObservationIgnored private var profileLoadTask: Task<Void, Never>?
    @ObservationIgnored private var profileLoadGeneration = 0

    init(
        coordinator: AppCoordinator,
        authService: AuthServiceProtocol,
        profileService: ProfileServiceProtocol,
        userService: UserServiceProtocol,
        cacheService: CacheService? = nil,
        progressRefreshState: ProgressRefreshState? = nil,
        activitySync: ActivitySyncProtocol? = nil,
        analyticsTracker: AnalyticsTracking? = nil,
        weightReminderScheduler: WeightReminderScheduling? = nil,
        waterReminderScheduler: WaterReminderScheduling? = nil
    ) {
        #if DEBUG
        print("ProfileViewModel init")
        #endif
        self.coordinator = coordinator
        self.authService = authService
        self.profileService = profileService
        self.userService = userService
        self.cacheService = cacheService
        self.progressRefreshState = progressRefreshState
        self.activitySync = activitySync
        self.analyticsTracker = analyticsTracker
        self.weightReminderScheduler = weightReminderScheduler
        self.waterReminderScheduler = waterReminderScheduler
    }

    #if DEBUG
    deinit { print("ProfileViewModel deinit") }
    #endif

    func trackScreen(_ screen: String) {
        analyticsTracker?.track(.screenView(screen: screen))
    }

    private func invalidateAggregateCaches() async {
        await cacheService?.remove("summary_today")
        await cacheService?.removeByPrefix("chart_summaries")
        await cacheService?.removeByPrefix("analytics_")
        await cacheService?.remove("goals_personalization")
        await cacheService?.remove("goals_preview")
        await cacheService?.removeByPrefix("goals_progress_")
        // A time zone change moves every calendar-day boundary, so cached weight
        // logs for all periods (Today/Week/Month/Custom) become stale, not just
        // the currently selected one.
        await cacheService?.removeByPrefix("weight_logs_")
        await cacheService?.removeByPrefix("period_goals_")
        await cacheService?.remove("goals_history")
        await cacheService?.remove("workout_last")
        await cacheService?.remove("workout_history")
        await cacheService?.remove("sleep_last_night")
        await cacheService?.remove("sleep_history_7d")
    }

    func loadData(forceRefresh: Bool = false) async {
        if !forceRefresh, let profileLoadTask {
            await profileLoadTask.value
            return
        }
        if forceRefresh {
            await cacheService?.remove("user")
            await cacheService?.remove("profile")
        }
        profileLoadGeneration &+= 1
        let generation = profileLoadGeneration
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performLoadData(forceRefresh: forceRefresh, generation: generation)
        }
        profileLoadTask = task
        await task.value
        if generation == profileLoadGeneration { profileLoadTask = nil }
    }

    private func performLoadData(forceRefresh: Bool, generation: Int) async {
        if !forceRefresh,
           let cachedUser: User = try? await cacheService?.get("user"),
           let cachedProfile: UserProfile = try? await cacheService?.get("profile") {
            guard generation == profileLoadGeneration else { return }
            email = cachedUser.email
            firstName = cachedUser.firstName
            lastName = cachedUser.lastName
            mapProfile(cachedProfile)
            state = .loaded(cachedProfile)
            return
        }
        let profileEmpty: Bool? = try? await cacheService?.get("profile_empty")
        if profileEmpty == true {
            guard generation == profileLoadGeneration else { return }
            clearForm()
            state = .empty
            return
        }

        state = .loading

        do {
            #if DEBUG
            print("[Network] ProfileVM getMe")
            #endif
            async let user = userService.getMe()
            #if DEBUG
            print("[Network] ProfileVM getMyProfile")
            #endif
            async let profile = profileService.getMyProfile()

            let (userResult, profileResult) = try await (user, profile)
            try Task.checkCancellation()
            guard generation == profileLoadGeneration else { return }

            email = userResult.email
            firstName = userResult.firstName
            lastName = userResult.lastName
            mapProfile(profileResult)
            PreferencesStore.shared.updateFromProfile(profileResult)
            
            if PreferencesStore.shared.autoUpdateTimeZone,
               profileResult.timeZone != TimeZone.current.identifier {
                await updateTimeZone(TimeZone.current.identifier)
            }
            try? await cacheService?.set("user", userResult, ttl: 1800)
            try? await cacheService?.set("profile", profileResult, ttl: 1800)
            await cacheService?.remove("profile_empty")
            state = .loaded(profileResult)

        } catch {
            guard generation == profileLoadGeneration else { return }
            let mapped = ErrorMapper.map(error)
            routeAuth(mapped)

            // A cancelled task is not a failure, so it must not overwrite the state
            // with an error the terminal switch would render as an empty view.
            if mapped == .cancelled { return }

            if case .notFound = mapped {
                try? await cacheService?.set("profile_empty", true, ttl: 1800)
                clearForm()
                state = .empty
            } else {
                if let cachedUser: User = try? await cacheService?.get("user", ignoreTTL: true),
                   let cachedProfile: UserProfile = try? await cacheService?.get("profile", ignoreTTL: true) {
                    email = cachedUser.email
                    firstName = cachedUser.firstName
                    lastName = cachedUser.lastName
                    mapProfile(cachedProfile)
                    state = .loaded(cachedProfile)
                } else {
                    let isEmptyFlag: Bool? = try? await cacheService?.get("profile_empty", ignoreTTL: true)
                    if isEmptyFlag == true {
                        clearForm()
                        state = .empty
                    } else {
                        state = .error(mapped)
                    }
                }
            }
        }
    }

    private func updateUser() async -> ErrorHandlingResult? {
        do {
            let user = try await userService.updateMe(
                email: email.isEmpty ? nil : email,
                password: nil,
                firstName: firstName.isEmpty ? nil : firstName,
                lastName: lastName.isEmpty ? nil : lastName
            )

            email = user.email
            firstName = user.firstName
            lastName = user.lastName
            await cacheService?.remove("user")
            await cacheService?.remove("profile")
            return nil

        } catch {
            let result = ErrorHandler.handle(
                error,
                supportedFields: ["email", "firstName", "lastName"]
            )

            if case .general(let appError) = result {
                routeAuth(appError)
            }

            return result
        }
    }

    func createProfile() async {
        fieldErrors.removeAll()

        let weightValue = canonicalWeight()
        let heightValue = canonicalHeight()
        let ageValue = Int(age)

        if weightValue == nil {
            setValidationError(for: "weight", isMissing: isBlank(weight))
        }
        if heightValue == nil {
            setValidationError(for: "height", isMissing: isBlank(height))
        }
        if ageValue == nil {
            setValidationError(for: "age", isMissing: isBlank(age))
        }
        if gender == nil { setRequiredError(for: "gender") }
        if goal == nil { setRequiredError(for: "goal") }
        if activityLevel == nil { setRequiredError(for: "activityLevel") }

        let goalPlan = makeGoalPlanRequest(currentWeightKg: weightValue)

        guard fieldErrors.isEmpty,
              let weight = weightValue,
              let height = heightValue,
              let age = ageValue,
              let gender,
              let goal,
              let activityLevel else {
            state = .empty
            return
        }

        state = .saving(nil)

        do {
            let profile = try await profileService.createProfile(
                weight: weight,
                height: height,
                age: age,
                gender: gender,
                goal: goal,
                activityLevel: activityLevel,
                preferredUnits: preferredUnits,
                goalPlan: goalPlan
            )

            mapProfile(profile)
            await weightReminderScheduler?.rescheduleAfterWeightUpdate()
            state = .loaded(profile)
            await cacheService?.remove("profile_empty")
            await cacheService?.remove("profile")
            await cacheService?.remove("goals")
            await invalidateAggregateCaches()
            progressRefreshState?.invalidateGoals()
            coordinator?.goToMain()

        } catch {
            switch ErrorHandler.handle(
                error,
                supportedFields: [
                    "weight",
                    "height",
                    "age",
                    "gender",
                    "goal",
                    "activityLevel"
                ]
            ) {
            case .fieldErrors(let errors):
                fieldErrors = errors
                state = .empty
            case .general(let appError):
                fieldErrors.removeAll()
                routeAuth(appError)
                state = .error(appError)
            }
        }
    }

    /// Saves the target plan after local validation, keeping API field errors in the same form state.
    @discardableResult
    func saveGoalPlan() async -> Bool {
        fieldErrors.removeAll()
        saveError = nil

        guard let request = makeGoalPlanRequest(currentWeightKg: originalWeightKg ?? canonicalWeight()) else {
            return false
        }

        do {
            let profile = try await profileService.updateGoalPlan(request)
            mapProfile(profile)
            state = .loaded(profile)
            await cacheService?.remove("profile")
            await cacheService?.remove("goals")
            await invalidateAggregateCaches()
            progressRefreshState?.invalidateGoalsRequiringManualDecision()
            return true
        } catch {
            switch ErrorHandler.handle(
                error,
                supportedFields: [
                    "targetWeightKg", "targetWeightMinKg", "targetWeightMaxKg",
                    "weeklyRateKg", "targetDate", "goalStartedAt"
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

    private func makeGoalPlanRequest(currentWeightKg: Double?) -> UpdateGoalPlanRequest? {
        let target = canonicalPlanWeight(targetWeight)
        let minimum = canonicalPlanWeight(maintainWeightMin)
        let maximum = canonicalPlanWeight(maintainWeightMax)
        let rate = normalized(weeklyRateKg)
        let date = targetDate.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedGoal = goal

        if !isBlank(targetWeight), target == nil { setValidationError(for: "targetWeightKg", isMissing: false) }
        if !isBlank(maintainWeightMin), minimum == nil { setValidationError(for: "targetWeightMinKg", isMissing: false) }
        if !isBlank(maintainWeightMax), maximum == nil { setValidationError(for: "targetWeightMaxKg", isMissing: false) }
        if !isBlank(weeklyRateKg), rate == nil || rate == 0 || (rate ?? 0) > 2 {
            setValidationError(for: "weeklyRateKg", isMissing: false)
        }
        if !date.isEmpty, (!Self.isDateOnly(date) || date < Self.todayDateOnly) {
            setValidationError(for: "targetDate", isMissing: false)
        }

        guard let selectedGoal else {
            setRequiredError(for: "goal")
            return nil
        }

        if (minimum == nil) != (maximum == nil) {
            setValidationError(for: "targetWeightMinKg", isMissing: false)
            setValidationError(for: "targetWeightMaxKg", isMissing: false)
        }
        if let minimum, let maximum {
            if minimum >= maximum || maximum - minimum < 0.5 || maximum - minimum > 10 {
                setValidationError(for: "targetWeightMinKg", isMissing: false)
                setValidationError(for: "targetWeightMaxKg", isMissing: false)
            }
        }

        switch selectedGoal {
        case .lose:
            if minimum != nil || maximum != nil {
                setValidationError(for: "targetWeightMinKg", isMissing: false)
            }
            if let target, let currentWeightKg, target >= currentWeightKg {
                setValidationError(for: "targetWeightKg", isMissing: false)
            }
            if !date.isEmpty, target == nil {
                setValidationError(for: "targetWeightKg", isMissing: false)
            }
        case .gain:
            if minimum != nil || maximum != nil {
                setValidationError(for: "targetWeightMinKg", isMissing: false)
            }
            if let target, let currentWeightKg, target <= currentWeightKg {
                setValidationError(for: "targetWeightKg", isMissing: false)
            }
            if !date.isEmpty, target == nil {
                setValidationError(for: "targetWeightKg", isMissing: false)
            }
        case .maintain:
            if let minimum, let maximum, let currentWeightKg,
               maximum < currentWeightKg - 15 || minimum > currentWeightKg + 15 {
                setValidationError(for: "targetWeightMinKg", isMissing: false)
            }
            if let target, let minimum, let maximum, target < minimum || target > maximum {
                setValidationError(for: "targetWeightKg", isMissing: false)
            } else if let target, let currentWeightKg, abs(target - currentWeightKg) > 10 {
                setValidationError(for: "targetWeightKg", isMissing: false)
            }
        }

        guard fieldErrors.isEmpty else { return nil }
        return UpdateGoalPlanRequest(
            goal: selectedGoal,
            targetWeightKg: target,
            targetWeightMinKg: minimum,
            targetWeightMaxKg: maximum,
            weeklyRateKg: rate,
            targetDate: date.isEmpty ? nil : date,
            goalStartedAt: goalStartedAt
        )
    }

    private func canonicalPlanWeight(_ text: String) -> Double? {
        guard let value = normalized(text) else { return nil }
        return UnitConversion.bodyWeightToKg(value, preferred: preferredUnits)
    }

    private static var todayDateOnly: String {
        AppDate.dateOnlyFormatter().string(from: .now)
    }

    private static func isDateOnly(_ value: String) -> Bool {
        let formatter = AppDate.dateOnlyFormatter()
        return formatter.string(from: formatter.date(from: value) ?? .distantPast) == value
    }

    func clearFieldError(_ field: String) {
        fieldErrors.clear(field)
    }

    private func setRequiredError(for field: String) {
        fieldErrors.set(
            FormErrorMapper.message(for: FieldErrorCode.required.rawValue),
            for: field
        )
    }

    private func setValidationError(for field: String, isMissing: Bool) {
        let code = isMissing
            ? FieldErrorCode.required
            : FieldErrorCode.invalidValue

        fieldErrors.set(
            FormErrorMapper.message(for: code.rawValue),
            for: field
        )
    }

    private func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func updateProfile() async -> ErrorHandlingResult? {
        do {
            let profile = try await profileService.updateMyProfile(
                height: canonicalHeight(),
                age: Int(age),
                gender: gender,
                goal: goal,
                activityLevel: activityLevel,
                preferredUnits: preferredUnits
            )

            mapProfile(profile)
            state = .loaded(profile)
            await cacheService?.remove("profile")
            await cacheService?.remove("goals")
            await invalidateAggregateCaches()
            progressRefreshState?.invalidateGoalsRequiringManualDecision()
            return nil

        } catch {
            // Only fields the edit form can actually change are treated as field
            // errors. Anything else falls back to the general error channel.
            let result = ErrorHandler.handle(
                error,
                supportedFields: ["height", "age", "gender"]
            )

            if case .general(let appError) = result {
                routeAuth(appError)
            }

            return result
        }
    }

    /// Saves the user block, then the profile block. Stops at the first failure so a
    /// half-applied edit never hides behind a dismissed form.
    func saveAll() async {
        let previousState = state

        fieldErrors.removeAll()
        saveError = nil
        state = .saving(nil)

        if let result = await updateUser() {
            finishSave(result, restoring: previousState)
            return
        }

        if let result = await updateProfile() {
            finishSave(result, restoring: previousState)
        }
    }

    private func finishSave(
        _ result: ErrorHandlingResult,
        restoring previousState: ProfileState
    ) {
        switch result {
        case .fieldErrors(let errors):
            fieldErrors = errors
            saveError = nil
            state = previousState

        case .general(.cancelled):
            state = previousState

        case .general(let error):
            fieldErrors.removeAll()
            saveError = error
            state = .error(error)
        }
    }

    func updatePreferredUnits() async {
        let newPrefs = preferredUnits
        let previousPrefs = lastSavedUnits
        unitsError = nil
        reformatMeasurements(from: previousPrefs, to: newPrefs)
        do {
            _ = try await profileService.updateMyProfile(
                height: nil,
                age: nil,
                gender: nil,
                goal: nil,
                activityLevel: nil,
                preferredUnits: newPrefs
            )
            lastSavedUnits = newPrefs
            await cacheService?.remove("profile")
        } catch {
            let mapped = ErrorMapper.map(error)
            routeAuth(mapped)
            preferredUnits = lastSavedUnits
            PreferencesStore.shared.preferredUnits = lastSavedUnits
            reformatMeasurements(from: newPrefs, to: lastSavedUnits)
            unitsError = mapped
        }
    }

    func updateTimeZone(_ timeZone: String) async {
        timeZoneError = nil
        do {
            _ = try await profileService.updateTimeZone(timeZone)
            PreferencesStore.shared.timeZone = timeZone
            await cacheService?.remove("profile")
            await invalidateTimeZoneCaches()
            // Time zone changes invalidate every calendar-day query, including
            // data already loaded in memory.
            progressRefreshState?.invalidateRequiringFullReload()
        } catch {
            let mapped = ErrorMapper.map(error)
            routeAuth(mapped)
            timeZoneError = mapped
        }
    }

    /// Drops everything that was calculated for calendar days and periods in
    /// the previous time zone. The `analytics_week` and `analytics_month` keys
    /// have no date in them, so without this they would keep results computed
    /// in the old zone until their TTL runs out.
    private func invalidateTimeZoneCaches() async {
        await invalidateAggregateCaches()
        await cacheService?.remove("food_today")
        await cacheService?.remove("water_today")
    }

    func setAutoUpdateTimeZone(_ enabled: Bool) async {
        PreferencesStore.shared.autoUpdateTimeZone = enabled
        if enabled {
            await updateTimeZone(TimeZone.current.identifier)
        }
    }

    func logout() async {
        weightReminderScheduler?.cancel()
        waterReminderScheduler?.cancel()
        activitySync?.stop()
        do {
            try await authService.logout()
        } catch {}
        await cacheService?.clear()
        coordinator?.goToAuth()
    }

    func deleteProfile() async {
        state = .saving(nil)

        do {
            try await profileService.deleteMyProfile()
            weightReminderScheduler?.cancel()
            waterReminderScheduler?.cancel()
            clearForm()
            state = .empty
            await cacheService?.remove("profile")
            await cacheService?.remove("goals")
            await invalidateAggregateCaches()
            try? await cacheService?.set("profile_empty", true, ttl: 1800)

        } catch {
            let mapped = ErrorMapper.map(error)
            routeAuth(mapped)
            state = .error(mapped)
        }
    }

    private func routeAuth(_ appError: AppError) {
        if appError == .unauthorized {
            coordinator?.goToAuth()
        }
    }
    
    private func mapProfile(_ profile: UserProfile) {
        let units = profile.preferredUnits ?? .default
        let formattedWeight = profile.weight.map { Self.formatBodyWeight(kg: $0, units: units) } ?? ""
        weight = formattedWeight
        originalWeightKg = profile.weight
        originalWeightText = formattedWeight
        originalHeightCm = profile.height
        height = profile.height.map { Self.formatBodyHeight(cm: Double($0), units: units) } ?? ""
        age = profile.age.map { String($0) } ?? ""
        gender = profile.gender
        goal = profile.goal
        activityLevel = profile.activityLevel
        originalTargetWeightKg = profile.targetWeightKg
        originalMaintainWeightMinKg = profile.targetWeightMinKg
        originalMaintainWeightMaxKg = profile.targetWeightMaxKg
        targetWeight = profile.targetWeightKg.map { Self.formatBodyWeight(kg: $0, units: units) } ?? ""
        maintainWeightMin = profile.targetWeightMinKg.map { Self.formatBodyWeight(kg: $0, units: units) } ?? ""
        maintainWeightMax = profile.targetWeightMaxKg.map { Self.formatBodyWeight(kg: $0, units: units) } ?? ""
        weeklyRateKg = profile.weeklyRateKg.map { String($0) } ?? ""
        targetDate = profile.targetDate ?? ""
        goalStartedAt = profile.goalStartedAt
        preferredUnits = profile.preferredUnits ?? .default
        lastSavedUnits = preferredUnits
    }

    /// Display value (kg or lb) typed by the user -> canonical kg sent to the backend.
    private func canonicalWeight() -> Double? {
        if weight == originalWeightText, let kg = originalWeightKg { return kg }
        guard let value = normalized(weight) else { return nil }
        return UnitConversion.bodyWeightToKg(value, preferred: preferredUnits)
    }

    /// Display value (cm or in) typed by the user -> canonical cm sent to the backend.
    private func canonicalHeight() -> Int? {
        guard let value = normalized(height) else { return nil }
        return Int(UnitConversion.heightToCm(value, preferred: preferredUnits).rounded())
    }

    private func normalized(_ text: String) -> Double? {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return UnitConversion.parseDecimal(text)
    }

    private static func formatBodyWeight(kg: Double, units: PreferredUnits) -> String {
        UnitConversion.formatBodyWeight(kg: kg, preferred: units)
    }

    private static func formatBodyHeight(cm: Double, units: PreferredUnits) -> String {
        if units.weight == .imperial {
            return String(format: "%.1f", UnitConversion.heightToDisplay(cm: cm, preferred: units))
        }
        return String(Int(cm.rounded()))
    }

    /// Keeps fields expressed in the selected unit system while retaining their canonical value.
    private func reformatMeasurements(from oldUnits: PreferredUnits, to newUnits: PreferredUnits) {
        guard oldUnits != newUnits else { return }

        if let originalWeightKg {
            let formattedWeight = Self.formatBodyWeight(kg: originalWeightKg, units: newUnits)
            weight = formattedWeight
            originalWeightText = formattedWeight
        }

        if let originalHeightCm {
            height = Self.formatBodyHeight(cm: Double(originalHeightCm), units: newUnits)
        }
        if let originalTargetWeightKg {
            targetWeight = Self.formatBodyWeight(kg: originalTargetWeightKg, units: newUnits)
        }
        if let originalMaintainWeightMinKg {
            maintainWeightMin = Self.formatBodyWeight(kg: originalMaintainWeightMinKg, units: newUnits)
        }
        if let originalMaintainWeightMaxKg {
            maintainWeightMax = Self.formatBodyWeight(kg: originalMaintainWeightMaxKg, units: newUnits)
        }
    }

    private func clearForm() {
        weight = ""
        height = ""
        age = ""
        targetWeight = ""
        maintainWeightMin = ""
        maintainWeightMax = ""
        weeklyRateKg = ""
        targetDate = ""
        goalStartedAt = nil
        gender = nil
        goal = nil
        activityLevel = nil
        originalWeightKg = nil
        originalWeightText = nil
        originalHeightCm = nil
        originalTargetWeightKg = nil
        originalMaintainWeightMinKg = nil
        originalMaintainWeightMaxKg = nil
    }
    
    func setPreviewState(_ newState: ProfileState) {
        state = newState
    }
}
