import Foundation
import Observation
import UIKit

enum TodayFoodState {
    case idle
    case loading
    case loaded([FoodEntry])
    case error(Error)
}

@Observable
@MainActor
final class TodayFoodViewModel {
    var state: TodayFoodState = .idle

    @ObservationIgnored private let service: FoodServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let cacheService: CacheService?

    init(service: FoodServiceProtocol, coordinator: AppCoordinator?, cacheService: CacheService? = nil) {
        print("TodayFoodViewModel init")
        self.service = service
        self.coordinator = coordinator
        self.cacheService = cacheService
    }

    deinit { print("TodayFoodViewModel deinit") }

    func loadToday() async {
        if let cached: [FoodEntry] = try? await cacheService?.get("food_today") {
            print("[TodayFoodVM] loadToday → cache HIT (\(cached.count) entries)")
            state = .loaded(cached)
            return
        }

        state = .loading
        do {
            print("[Network] TodayFoodVM loadToday")
            let food = try await service.getTodayFood()
            try? await cacheService?.set("food_today", food, ttl: 300)
            print("[TodayFoodVM] loadToday → network OK (\(food.count) entries)")
            state = .loaded(food)
        } catch {
            if let cached: [FoodEntry] = try? await cacheService?.get("food_today", ignoreTTL: true) {
                print("[TodayFoodVM] loadToday → fallback to stale cache (\(cached.count) entries)")
                state = .loaded(cached)
            } else {
                print("[TodayFoodVM] loadToday → FAIL, no cache")
                state = .error(error)
            }
        }
    }

    func reloadAfterAdd() async {
        await cacheService?.remove("food_today")
        await cacheService?.remove("dashboard_today")
        await cacheService?.remove("summary_today")
        await cacheService?.remove("chart_today")
        await cacheService?.removeByPrefix("chart_summaries")
        await cacheService?.removeByPrefix("analytics_")
        await loadToday()
    }

    func updateFood(id: String, name: String?, calories: Int?, protein: Int?, fat: Int?, carbs: Int?, grams: Int?, categoryName: String? = nil, image: UIImage?) async {
        do {
            print("[Network] TodayFoodVM updateFood")
            var imageUrl: String?
            if let image, let data = image.jpegData(compressionQuality: 0.8) {
                imageUrl = try await service.uploadImage(data)
            }
            try await service.updateFoodEntry(
                id: id,
                name: name,
                calories: calories,
                protein: protein,
                fat: fat,
                carbs: carbs,
                grams: grams,
                foodId: nil,
                date: nil,
                imageUrl: imageUrl,
                categoryName: categoryName
            )
            await reloadAfterAdd()
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
            print("[Network] TodayFoodVM deleteFood")
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            try await service.deleteFoodEntry(id: id, date: df.string(from: Date()))
            AnalyticsManager.shared.track(.foodDeleted)
            await reloadAfterAdd()
        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator?.goToAuth()
            }
            state = .error(error)
        } catch {
            state = .error(error)
        }
    }

    func setPreviewState(_ newState: TodayFoodState) {
        state = newState
    }
}
