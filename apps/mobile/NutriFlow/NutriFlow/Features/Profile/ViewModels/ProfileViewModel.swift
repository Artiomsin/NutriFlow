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
    
    @ObservationIgnored private let authService: AuthServiceProtocol
    @ObservationIgnored private let profileService: ProfileServiceProtocol
    @ObservationIgnored private let userService: UserServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let cacheService: CacheService?

    init(
        coordinator: AppCoordinator,
        authService: AuthServiceProtocol,
        profileService: ProfileServiceProtocol,
        userService: UserServiceProtocol,
        cacheService: CacheService? = nil
    ) {
        print("ProfileViewModel init")
        self.coordinator = coordinator
        self.authService = authService
        self.profileService = profileService
        self.userService = userService
        self.cacheService = cacheService
    }

    deinit { print("ProfileViewModel deinit") }

    func loadData() async {
        if let cached: UserProfile = try? await cacheService?.get("profile") {
            email = cached.email ?? ""
            firstName = cached.firstName ?? ""
            lastName = cached.lastName ?? ""
            mapProfile(cached)
            state = .loaded(cached)
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
                if let cached: UserProfile = try? await cacheService?.get("profile", ignoreTTL: true) {
                    email = cached.email ?? ""
                    firstName = cached.firstName ?? ""
                    lastName = cached.lastName ?? ""
                    mapProfile(cached)
                    state = .loaded(cached)
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
            if let cached: UserProfile = try? await cacheService?.get("profile", ignoreTTL: true) {
                email = cached.email ?? ""
                firstName = cached.firstName ?? ""
                lastName = cached.lastName ?? ""
                mapProfile(cached)
                state = .loaded(cached)
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
            await cacheService?.remove("profile")

        } catch {
            state = .error(error)
        }
    }

    func createProfile() async {
        state = .saving(nil)

        do {
            let profile = try await profileService.createProfile(
                weight: Double(weight),
                height: Int(height),
                age: Int(age),
                gender: gender,
                goal: goal,
                activityLevel: activityLevel
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
                weight: Double(weight),
                height: Int(height),
                age: Int(age),
                gender: gender,
                goal: goal,
                activityLevel: activityLevel
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

    func logout() async {
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
        weight = profile.weight.map { String($0) } ?? ""
        height = profile.height.map { String($0) } ?? ""
        age = profile.age.map { String($0) } ?? ""
        gender = profile.gender
        goal = profile.goal
        activityLevel = profile.activityLevel
    }

    private func clearForm() {
        weight = ""
        height = ""
        age = ""
        gender = nil
        goal = nil
        activityLevel = nil
    }
    
    func setPreviewState(_ newState: ProfileState) {
        state = newState
    }
}
