
import Foundation

@MainActor
final class FoodViewModel: ObservableObject {
    
    @Published private(set) var state: FoodState = .idle
    
    @Published var name: String = ""
    @Published var calories: String = ""
    @Published var protein: String = ""
    @Published var fat: String = ""
    @Published var carbs: String = ""
    
    private let session: SessionManager
    private let service: FoodServiceProtocol
    
    var onUnauthorized: (() -> Void)?
    
    init (session: SessionManager, service: FoodServiceProtocol){
        self.session = session
        self.service = service
    }
    
    func loadToday() async {
        
        guard let token = session.accessToken() else {
            state = .error(APIError.unauthorized)
            return
        }
        
        state = .loading
        
        do {
            let food = try await service.getTodayFood(token: token)
            state = .loaded(food)
            
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
    
    func createFood() async {
        
        guard let token = session.accessToken() else {
            state = .error(APIError.unauthorized)
            return
        }
        
        guard let caloriesInt = Int(calories) else { return }
        
        state = .saving
        
        do {
            _ = try await service.createFoodEntry(
                token: token,
                name: name,
                calories: caloriesInt,
                protein: Int(protein),
                fat: Int(fat),
                carbs: Int(carbs)
            )
            
            await loadToday()
            clearForm()
            
        } catch {
            state = .error(error)
        }
    }
    
    func deleteFood(id: String) async {
        
        guard let token = session.accessToken() else {
            state = .error(APIError.unauthorized)
            return
        }
        
        do {
            _ = try await service.deleteFoodEntry(token: token, id: id)
            await loadToday()
            
        } catch {
            state = .error(error)
        }
    }
    
    private func clearForm() {
        
        name = ""
        calories = ""
        protein = ""
        fat = ""
        carbs = ""
    }
    
    func setPreviewState(_ newState: FoodState) {
        state = newState
    }
}
