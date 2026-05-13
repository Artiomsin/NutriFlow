import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    
    @Published private(set) var state: ProfileState = .loading
    
    @Published var weight: String = ""
    @Published var height: String = ""
    @Published var age: String = ""
    
    @Published var goal: Goal?
    @Published var activityLevel: ActivityLevel?
    
    var onUnauthorized: (() -> Void)?
    
    private let service: ProfileServiceProtocol
    private var session: SessionManager
    
    init(session: SessionManager, service: ProfileServiceProtocol) {
        self.session = session
        self.service = service
    }
    
    func configure(session: SessionManager) {
        self.session = session
    }
    
    func loadProfile() async {
        
        guard let token = session.accessToken() else {
            state = .empty
            return
        }
        
        state = .loading
        
        do {
            let profile = try await service.getMyProfile(token: token)
            state = .loaded(profile)
            mapToForm(profile)
            
        } catch let error as APIError {
            switch error {
            case .notFound:
                state = .empty
            case .unauthorized:
                session.logout()
                onUnauthorized?()
            default:
                state = .error(error)
            }
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
            let profile = try await service.createProfile(
                token: token,
                weight: Double(weight),
                height: Int(height),
                age: Int(age),
                goal: goal,
                activityLevel: activityLevel
            )
            
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
            let profile = try await service.updateMyProfile(
                token: token,
                weight: Double(weight),
                height: Int(height),
                age: Int(age),
                goal: goal,
                activityLevel: activityLevel
            )
            
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
            _ = try await service.deleteMyProfile(token: token)
            
            state = .empty
            clearForm()
            
        } catch {
            state = .error(error)
        }
    }
    
    
    private func mapToForm(_ profile: UserProfile) {
        
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

#if DEBUG
func setPreviewState(_ state: ProfileState) {
    self.state = state
}
#endif
    
}
