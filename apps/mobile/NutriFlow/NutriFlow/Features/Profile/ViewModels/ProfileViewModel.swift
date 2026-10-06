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

    func loadData() async {
        if let cachedUser: User = try? await cacheService?.get("user"),
           let cachedProfile: UserProfile = try? await cacheService?.get("profile") {
            email = cachedUser.email
            firstName = cachedUser.firstName
            lastName = cachedUser.lastName
            mapProfile(cachedProfile)
            state = .loaded(cachedProfile)
            return
        }
        let profileEmpty: Bool? = try? await cacheService?.get("profile_empty")
        if profileEmpty == true {
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

    @discardableResult
    func updateUser() async -> AppError? {
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
            let mapped = ErrorMapper.map(error)
            routeAuth(mapped)
            return mapped
        }
    }

    func createProfile() async {
        state = .saving(nil)

        guard let weight = canonicalWeight(),
              let height = canonicalHeight(),
              let age = Int(age),
              let gender,
              let goal,
              let activityLevel else {
            state = .error(.validation(message: "Fill in weight, height, age, gender, goal, and activity level."))
            return
        }

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
            let mapped = ErrorMapper.map(error)
            routeAuth(mapped)
            state = .error(mapped)
        }
    }

    @discardableResult
    func updateProfile() async -> AppError? {
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
            let mapped = ErrorMapper.map(error)
            routeAuth(mapped)
            return mapped
        }
    }

    /// Saves the user block, then the profile block. Stops at the first failure so a
    /// half-applied edit never hides behind a dismissed form.
    func saveAll() async {
        state = .saving(nil)
        saveError = nil

        if let error = await updateUser() {
            saveError = error
            state = .error(error)
            return
        }

        if let error = await updateProfile() {
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
