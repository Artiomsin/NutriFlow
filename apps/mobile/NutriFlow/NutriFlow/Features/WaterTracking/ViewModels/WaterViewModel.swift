import Foundation
import Observation

@Observable
@MainActor
final class WaterViewModel {

    var state: WaterState = .idle
    var amountMl: String = ""
    
    @ObservationIgnored private let service: WaterTrackingServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let cacheService: CacheService?

    init(coordinator: AppCoordinator, service: WaterTrackingServiceProtocol, cacheService: CacheService? = nil) {
        print("WaterViewModel init")
        self.coordinator = coordinator
        self.service = service
        self.cacheService = cacheService
    }

    deinit { print("WaterViewModel deinit") }
    
    func loadToday() async {
        if let cached: [WaterEntry] = try? await cacheService?.get("water_today") {
            state = .loaded(cached)
            return
        }

        state = .loading
        do {
            #if DEBUG
            print("[Network] WaterVM loadToday")
            #endif
            let entries = try await service.getTodayWater()
            try? await cacheService?.set("water_today", entries, ttl: 300)
            state = .loaded(entries)
        } catch {
            if let cached: [WaterEntry] = try? await cacheService?.get("water_today", ignoreTTL: true) {
                state = .loaded(cached)
            } else {
                state = .error(error)
            }
        }
    }

    func createWater() async {
        guard let ml = Int(amountMl) else {
            state = .error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Количество должно быть числом"]))
            return
        }

        state = .saving

        do {
            #if DEBUG
            print("[Network] WaterVM createWater")
            #endif
            try await service.createWaterEntry(amountMl: ml)
            AnalyticsManager.shared.track(.waterAdded(amountMl: ml))
            await cacheService?.remove("water_today")
            await cacheService?.remove("dashboard_today")
            await cacheService?.remove("summary_today")
            await cacheService?.remove("chart_today")
            await cacheService?.removeByPrefix("chart_summaries")
            await cacheService?.removeByPrefix("analytics_")

            let entries = try await service.getTodayWater()
            try? await cacheService?.set("water_today", entries, ttl: 300)
            state = .loaded(entries)
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

    func deleteWater(id: String) async {
        do {
            #if DEBUG
            print("[Network] WaterVM deleteWater")
            #endif
            try await service.deleteWaterEntry(id: id)
            AnalyticsManager.shared.track(.waterDeleted)
            await cacheService?.remove("water_today")
            await cacheService?.remove("dashboard_today")
            await cacheService?.remove("summary_today")
            await cacheService?.remove("chart_today")
            await cacheService?.removeByPrefix("chart_summaries")
            await cacheService?.removeByPrefix("analytics_")

            let entries = try await service.getTodayWater()
            try? await cacheService?.set("water_today", entries, ttl: 300)
            state = .loaded(entries)
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
        amountMl = ""
    }
    
    func setPreviewState(_ newState: WaterState) {
        state = newState
    }
}
