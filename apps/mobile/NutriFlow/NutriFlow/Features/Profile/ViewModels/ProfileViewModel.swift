import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    
    @Published var state: ProfileState = .loading
    
    @Published var weight: String = ""
    @Published var height: String = ""
    @Published var age: String = ""
    
    @Published var email: String = ""
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    
    @Published var goal: Goal?
    @Published var activityLevel: ActivityLevel?
    
    var onUnauthorized: (() -> Void)?
    
    private let profileService: ProfileServiceProtocol
    private let userService: UserServiceProtocol
    private var session: SessionManager
    
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
                state = .empty
                return
            }

            state = .loading

            do {
                
                async let user = userService.getMe(token: token)
                async let profile = profileService.getMyProfile(token: token)

                let (u, p) = try await (user, profile)

            
                email = u.email
                firstName = u.firstName
                lastName = u.lastName

             
                mapProfile(p)

                state = .loaded(p)

            } catch let error as APIError {
                if case .unauthorized = error {
                    session.logout()
                    onUnauthorized?()
                }

                state = .error(error)
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
