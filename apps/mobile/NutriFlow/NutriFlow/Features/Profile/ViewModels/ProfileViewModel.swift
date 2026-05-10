import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    
    @Published var state: ProfileState = .loading
    
    @Published var weight: String = ""
    @Published var height: String = ""
    @Published var age: String = ""
    
    @Published var goal: Goal?
    @Published var activityLevel: ActivityLevel?
    
    private var service: ProfileService?
    private var session: SessionManager?
    
    init() {}
    
    convenience init(session: SessionManager) {
        self.init()
        self.session = session
        self.service = ProfileService()
    }
    
    func configure(session: SessionManager) {
        self.session = session
        self.service = ProfileService()
    }
    
    private func getSession() -> SessionManager {
        guard let session = session else {
            fatalError("Session not configured")
        }
        return session
    }
    
    
    func loadProfile() async {
        
        guard let token = getSession().accessToken else {
            state = .empty
            return
        }
        
        state = .loading
        
        do {
            let profile = try await service?.getMyProfile(token: token)
            
            if let profile = profile {
                state = .loaded(profile)
                mapToForm(profile)
            }
            
        } catch {
            state = .error(error)
        }
    }
    
    
    func createProfile() async {
        
        guard let token = getSession().accessToken else {
            state = .error(APIError.unauthorized)
            return
        }
        
        state = .saving(nil)
        
        do {
            let profile = try await service?.createProfile(
                token: token,
                weight: Double(weight),
                height: Int(height),
                age: Int(age),
                goal: goal,
                activityLevel: activityLevel
            )
            
            if let profile = profile {
                state = .loaded(profile)
            }
            
        } catch {
            state = .error(error)
        }
    }
    
    
    func updateProfile() async {
        
        guard let token = getSession().accessToken else {
            state = .error(APIError.unauthorized)
            return
        }
        
        state = .saving(nil)
        
        do {
            let profile = try await service?.updateMyProfile(
                token: token,
                weight: Double(weight),
                height: Int(height),
                age: Int(age),
                goal: goal,
                activityLevel: activityLevel
            )
            
            if let profile = profile {
                state = .loaded(profile)
            }
            
        } catch {
            state = .error(error)
        }
    }
    
    
    func deleteProfile() async {
        
        guard let token = getSession().accessToken else {
            state = .error(APIError.unauthorized)
            return
        }
        
        state = .saving(nil)
        
        do {
            try await service?.deleteMyProfile(token: token)
            
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
}