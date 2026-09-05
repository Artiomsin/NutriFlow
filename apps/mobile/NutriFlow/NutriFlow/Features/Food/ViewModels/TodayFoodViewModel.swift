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
    @ObservationIgnored private let progressRefreshState: ProgressRefreshState?

    init(service: FoodServiceProtocol, coordinator: AppCoordinator?, cacheService: CacheService? = nil, progressRefreshState: ProgressRefreshState? = nil) {
        print("TodayFoodViewModel init")
        self.service = service
        self.coordinator = coordinator
        self.cacheService = cacheService
        self.progressRefreshState = progressRefreshState
    }

    deinit { print("TodayFoodViewModel deinit") }

    func loadToday() async {
        if let cached: [FoodEntry] = try? await cacheService?.get("food_today") {
            print("[TodayFoodVM] loadToday → cache HIT (\(cached.count) entries)")
            state = .loaded(cached)
            return
        }

        if case .loaded = state {} else { state = .loading }
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
            } else if case .loaded = state {
                print("[TodayFoodVM] loadToday → FAIL, keeping existing data")
            } else {
                print("[TodayFoodVM] loadToday → FAIL, no cache")
                state = .error(error)
            }
        }
    }

    func reloadAfterMutation() async {
        await cacheService?.remove("food_today")
        await cacheService?.remove("dashboard_today")
        await cacheService?.remove("summary_today")
        await cacheService?.remove("chart_today")
        await cacheService?.removeByPrefix("chart_summaries")
        await cacheService?.removeByPrefix("analytics_")
        await loadToday()
    }

    func notifyDataMutated() {
        progressRefreshState?.invalidate()
    }

    @discardableResult
    func deleteFood(id: String) async -> Bool {
        do {
            print("[Network] TodayFoodVM deleteFood")
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            try await service.deleteFoodEntry(id: id, date: df.string(from: Date()))
            AnalyticsManager.shared.track(.foodDeleted)
            await reloadAfterMutation()
            notifyDataMutated()
            return true
        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator?.goToAuth()
            }
            state = .error(error)
            return false
        } catch {
            state = .error(error)
            return false
        }
    }

    func setPreviewState(_ newState: TodayFoodState) {
        state = newState
    }
}
