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
    var saveError: AppError?
    var unitsError: AppError?
    var fieldErrors = FormFieldErrors()

    private var originalWeightKg: Double?
    private var originalWeightText: String?
    @ObservationIgnored private var lastSavedUnits: PreferredUnits = .default

    @ObservationIgnored private let authService: AuthServiceProtocol
    @ObservationIgnored private let profileService: ProfileServiceProtocol
    @ObservationIgnored private let userService: UserServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let cacheService: CacheService?
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
            // This request only runs after the authenticated profile read has
            // succeeded, so the token interceptor is ready to attach a token.
            if profileResult.timeZone != TimeZone.current.identifier {
                try? await profileService.updateTimeZone(TimeZone.current.identifier)
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
                preferredUnits: preferredUnits
            )

            mapProfile(profile)
            await weightReminderScheduler?.rescheduleAfterWeightUpdate()
            state = .loaded(profile)
            await cacheService?.remove("profile_empty")
            await cacheService?.remove("profile")
            await cacheService?.remove("goals")
            await invalidateAggregateCaches()
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
        unitsError = nil
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
            // SettingsView writes PreferencesStore before calling this method, so the
            // rollback has to cover both places or the toggle snaps back on next launch.
            preferredUnits = lastSavedUnits
            PreferencesStore.shared.preferredUnits = lastSavedUnits
            unitsError = mapped
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
        height = profile.height.map { Self.formatBodyHeight(cm: Double($0), units: units) } ?? ""
        age = profile.age.map { String($0) } ?? ""
        gender = profile.gender
        goal = profile.goal
        activityLevel = profile.activityLevel
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
        if units.weight == .imperial {
            return String(format: "%.1f", UnitConversion.bodyWeightToDisplay(kg: kg, preferred: units))
        }
        return String(Int(kg.rounded()))
    }

    private static func formatBodyHeight(cm: Double, units: PreferredUnits) -> String {
        if units.weight == .imperial {
            return String(format: "%.1f", UnitConversion.heightToDisplay(cm: cm, preferred: units))
        }
        return String(Int(cm.rounded()))
    }

    private func clearForm() {
        weight = ""
        height = ""
        age = ""
        gender = nil
        goal = nil
        activityLevel = nil
        originalWeightKg = nil
        originalWeightText = nil
    }
    
    func setPreviewState(_ newState: ProfileState) {
        state = newState
    }
}
