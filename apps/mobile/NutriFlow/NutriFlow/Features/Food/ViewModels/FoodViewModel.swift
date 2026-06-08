import Foundation
import Observation

@Observable
@MainActor
final class FoodViewModel {
    
    var state: FoodState = .idle
    
    var name: String = ""
    var calories: String = ""
    var protein: String = ""
    var fat: String = ""
    var carbs: String = ""
    
    @ObservationIgnored private let service: FoodServiceProtocol
    
    init(service: FoodServiceProtocol) {
        self.service = service
    }
    
    func loadToday() async {
        state = .loading
        
        do {
            let food = try await service.getTodayFood()
            state = .loaded(food)
        } catch {
            state = .error(error)
        }
    }
    
    func createFood() async {
        guard let caloriesInt = Int(calories) else {
            state = .error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Калории должны быть числом"]))
            return
        }
        
        state = .saving
        
        do {
            try await service.createFoodEntry(
                name: name,
                calories: caloriesInt,
                protein: Int(protein),
                fat: Int(fat),
                carbs: Int(carbs)
            )

            AnalyticsService.shared.track(.foodAdded(name: name, calories: caloriesInt))
            await loadToday()
            clearForm()
        } catch {
            state = .error(error)
        }
    }
    
    func deleteFood(id: String) async {
        do {
            try await service.deleteFoodEntry(id: id)
            AnalyticsService.shared.track(.foodDeleted)
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
