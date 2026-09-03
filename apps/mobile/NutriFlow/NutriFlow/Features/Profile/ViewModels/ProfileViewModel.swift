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

    private var originalWeightKg: Double?
    private var originalWeightText: String?

    @ObservationIgnored private let authService: AuthServiceProtocol
    @ObservationIgnored private let profileService: ProfileServiceProtocol
    @ObservationIgnored private let userService: UserServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let cacheService: CacheService?
    @ObservationIgnored private var backgroundSyncer: ActivityBackgroundSyncer?

    init(
        coordinator: AppCoordinator,
        authService: AuthServiceProtocol,
        profileService: ProfileServiceProtocol,
        userService: UserServiceProtocol,
        cacheService: CacheService? = nil,
        backgroundSyncer: ActivityBackgroundSyncer? = nil
    ) {
        print("ProfileViewModel init")
        self.coordinator = coordinator
        self.authService = authService
        self.profileService = profileService
        self.userService = userService
        self.cacheService = cacheService
        self.backgroundSyncer = backgroundSyncer
    }

    deinit { print("ProfileViewModel deinit") }

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
            try? await cacheService?.set("user", userResult, ttl: 1800)
            try? await cacheService?.set("profile", profileResult, ttl: 1800)
            await cacheService?.remove("profile_empty")
            state = .loaded(profileResult)

        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator?.goToAuth()
            }
            if case .notFound = error {
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
                        state = .error(error)
                    }
                }
            }
        } catch {
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
                    state = .error(error)
                }
            }
        }
    }

    func updateUser() async {
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

        } catch {
            state = .error(error)
        }
    }

    func createProfile() async {
        state = .saving(nil)

        do {
            let profile = try await profileService.createProfile(
                weight: canonicalWeight(),
                height: canonicalHeight(),
                age: Int(age),
                gender: gender,
                goal: goal,
                activityLevel: activityLevel,
                preferredUnits: preferredUnits
            )

            mapProfile(profile)
            state = .loaded(profile)
            await cacheService?.remove("profile_empty")
            await cacheService?.remove("profile")
            await cacheService?.remove("goals")
            AnalyticsManager.shared.track(.profileCreated)
            coordinator?.goToMain()

        } catch {
            state = .error(error)
        }
    }

    func updateProfile() async {
        state = .saving(nil)

        do {
            let profile = try await profileService.updateMyProfile(
                weight: canonicalWeight(),
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
            AnalyticsManager.shared.track(.profileUpdated)

        } catch {
            state = .error(error)
        }
    }

    func updatePreferredUnits() async {
        let newPrefs = preferredUnits
        do {
            _ = try await profileService.updateMyProfile(
                weight: nil,
                height: nil,
                age: nil,
                gender: nil,
                goal: nil,
                activityLevel: nil,
                preferredUnits: newPrefs
            )
            await cacheService?.remove("profile")
        } catch {}
    }

    func logout() async {
        backgroundSyncer?.stop()
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
            clearForm()
            state = .empty
            await cacheService?.remove("profile")
            await cacheService?.remove("goals")
            try? await cacheService?.set("profile_empty", true, ttl: 1800)

        } catch {
            state = .error(error)
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
