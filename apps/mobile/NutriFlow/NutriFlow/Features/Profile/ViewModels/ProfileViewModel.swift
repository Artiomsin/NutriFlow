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
    
    var goal: Goal?
    var activityLevel: ActivityLevel?
    
    @ObservationIgnored private let authService: AuthServiceProtocol
    @ObservationIgnored private let profileService: ProfileServiceProtocol
    @ObservationIgnored private let userService: UserServiceProtocol
    @ObservationIgnored private let coordinator: AppCoordinator

    init(
        coordinator: AppCoordinator,
        authService: AuthServiceProtocol,
        profileService: ProfileServiceProtocol,
        userService: UserServiceProtocol
    ) {
        self.coordinator = coordinator
        self.authService = authService
        self.profileService = profileService
        self.userService = userService
    }

    func loadData() async {
        state = .loading

        do {
            async let user = userService.getMe()
            async let profile = profileService.getMyProfile()

            let (userResult, profileResult) = try await (user, profile)

            email = userResult.email
            firstName = userResult.firstName
            lastName = userResult.lastName
            mapProfile(profileResult)
            state = .loaded(profileResult)

        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator.goToAuth()
            }
            if case .notFound = error {
                clearForm()
                state = .empty
            } else {
                state = .error(error)
            }
        } catch {
            state = .error(error)
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
                goal: goal,
                activityLevel: activityLevel
            )

            mapProfile(profile)
            state = .loaded(profile)
            AnalyticsService.shared.track(.profileCreated)
            coordinator.goToMain()

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
                goal: goal,
                activityLevel: activityLevel
            )

            mapProfile(profile)
            state = .loaded(profile)
            AnalyticsService.shared.track(.profileUpdated)

        } catch {
            state = .error(error)
        }
    }

    func logout() async {
        do {
            try await authService.logout()
        } catch {}
        coordinator.goToAuth()
    }

    func deleteProfile() async {
        state = .saving(nil)

        do {
            try await profileService.deleteMyProfile()
            clearForm()
            state = .empty

        } catch {
            state = .error(error)
        }
    }

    private func mapProfile(_ profile: UserProfile) {
        weight = profile.weight.map { String($0) } ?? ""
        height = profile.height.map { String($0) } ?? ""
        age = profile.age.map { String($0) } ?? ""
        goal = profile.goal
        activityLevel = profile.activityLevel
    }

    private func clearForm() {
        weight = ""
        height = ""
        age = ""
        goal = nil
        activityLevel = nil
    }
    
    func setPreviewState(_ newState: ProfileState) {
        state = newState
    }
}
