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
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let cacheService: CacheService?
    
    init(coordinator: AppCoordinator, service: FoodServiceProtocol, cacheService: CacheService? = nil) {
        print("FoodViewModel init")
        self.coordinator = coordinator
        self.service = service
        self.cacheService = cacheService
    }

    deinit { print("FoodViewModel deinit") }
    
    func loadToday() async {
        if let cached: [FoodEntry] = try? await cacheService?.get("food_today") {
            #if DEBUG
            print("[FoodVM] loadToday → cache HIT (\(cached.count) entries)")
            #endif
            state = .loaded(cached)
            return
        }

        state = .loading
        do {
            #if DEBUG
            print("[Network] FoodVM loadToday")
            #endif
            let food = try await service.getTodayFood()
            try? await cacheService?.set("food_today", food, ttl: 300)
            #if DEBUG
            print("[FoodVM] loadToday → network OK (\(food.count) entries)")
            #endif
            state = .loaded(food)
        } catch {
            if let cached: [FoodEntry] = try? await cacheService?.get("food_today", ignoreTTL: true) {
                #if DEBUG
                print("[FoodVM] loadToday → fallback to stale cache (\(cached.count) entries)")
                #endif
                state = .loaded(cached)
            } else {
                #if DEBUG
                print("[FoodVM] loadToday → FAIL, no cache")
                #endif
                state = .error(error)
            }
        }
    }
    
    func createFood() async {
        guard let caloriesInt = Int(calories) else {
            state = .error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Калории должны быть числом"]))
            return
        }
        
        state = .saving
        
        do {
            #if DEBUG
            print("[Network] FoodVM createFood")
            #endif
            try await service.createFoodEntry(
                name: name,
                calories: caloriesInt,
                protein: Int(protein),
                fat: Int(fat),
                carbs: Int(carbs)
            )

            AnalyticsManager.shared.track(.foodAdded(name: name, calories: caloriesInt))
            await cacheService?.remove("food_today")
            await cacheService?.remove("dashboard_today")
            await cacheService?.remove("summary_today")
            await cacheService?.remove("chart_today")
            await cacheService?.removeByPrefix("chart_summaries")
            await cacheService?.removeByPrefix("analytics_")
            await loadToday()
            clearForm()
        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator?.goToAuth()
            }
            state = .error(error)
        } catch {
            state = .error(error)
        }
    }
    
    func deleteFood(id: String) async {
        do {
            #if DEBUG
            print("[Network] FoodVM deleteFood")
            #endif
            try await service.deleteFoodEntry(id: id)
            AnalyticsManager.shared.track(.foodDeleted)
            await cacheService?.remove("food_today")
            await cacheService?.remove("dashboard_today")
            await cacheService?.remove("summary_today")
            await cacheService?.remove("chart_today")
            await cacheService?.removeByPrefix("chart_summaries")
            await cacheService?.removeByPrefix("analytics_")
            await loadToday()
        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator?.goToAuth()
            }
            state = .error(error)
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
