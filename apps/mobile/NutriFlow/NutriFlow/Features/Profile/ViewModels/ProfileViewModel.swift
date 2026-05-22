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
    
    @ObservationIgnored private let profileService: ProfileServiceProtocol
    @ObservationIgnored private let userService: UserServiceProtocol
    @ObservationIgnored private var session: SessionManager
    @ObservationIgnored var onUnauthorized: (() -> Void)?
    
    init(
        session: SessionManager,
        profileService: ProfileServiceProtocol,
        userService: UserServiceProtocol
    ) {
        self.session = session
        self.profileService = profileService
        self.userService = userService
    }
    
    func loadData() async {
        guard let token = session.accessToken() else {
            clearForm()
            state = .empty
            return
        }

        state = .loading

        do {
            async let user = userService.getMe(token: token)
            async let profile = profileService.getMyProfile(token: token)

            let (userResult, profileResult) = try await (user, profile)

            email = userResult.email
            firstName = userResult.firstName
            lastName = userResult.lastName
            mapProfile(profileResult)
            state = .loaded(profileResult)

        } catch let error as APIError {
            if case .unauthorized = error {
                session.logout()
                onUnauthorized?()
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
        guard let token = session.accessToken() else {
            state = .error(APIError.unauthorized)
            return
        }

        do {
            let user = try await userService.updateMe(
                token: token,
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
        guard let token = session.accessToken() else {
            state = .error(APIError.unauthorized)
            return
        }

        state = .saving(nil)

        do {
            let profile = try await profileService.createProfile(
                token: token,
                weight: Double(weight),
                height: Int(height),
                age: Int(age),
                goal: goal,
                activityLevel: activityLevel
            )

            mapProfile(profile)
            state = .loaded(profile)

        } catch {
            state = .error(error)
        }
    }

    func updateProfile() async {
        guard let token = session.accessToken() else {
            state = .error(APIError.unauthorized)
            return
        }

        state = .saving(nil)

        do {
            let profile = try await profileService.updateMyProfile(
                token: token,
                weight: Double(weight),
                height: Int(height),
                age: Int(age),
                goal: goal,
                activityLevel: activityLevel
            )

            mapProfile(profile)
            state = .loaded(profile)

        } catch {
            state = .error(error)
        }
    }

    func deleteProfile() async {
        guard let token = session.accessToken() else {
            state = .error(APIError.unauthorized)
            return
        }

        state = .saving(nil)

        do {
            _ = try await profileService.deleteMyProfile(token: token)
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