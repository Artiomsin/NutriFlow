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
    @ObservationIgnored private let progressRefreshState: ProgressRefreshState?
    @ObservationIgnored private let analyticsTracker: AnalyticsTracking?

    init(coordinator: AppCoordinator, service: WaterTrackingServiceProtocol, cacheService: CacheService? = nil, progressRefreshState: ProgressRefreshState? = nil, analyticsTracker: AnalyticsTracking? = nil) {
        print("WaterViewModel init")
        self.coordinator = coordinator
        self.service = service
        self.cacheService = cacheService
        self.progressRefreshState = progressRefreshState
        self.analyticsTracker = analyticsTracker
    }

    deinit { print("WaterViewModel deinit") }

    func trackScreenView() {
        analyticsTracker?.track(.screenView(screen: "add_water"))
    }
    
    func loadToday() async {
        if let cached: [WaterEntry] = try? await cacheService?.get("water_today") {
            state = .loaded(cached)
            return
        }

        if case .loaded = state {} else { state = .loading }
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
            } else if case .loaded = state {
                print("[WaterVM] loadToday → FAIL, keeping existing data | \(error)")
            } else {
                print("[WaterVM] loadToday → FAIL, no cache | \(error)")
                state = .error(error)
            }
        }
    }

    @discardableResult
    func createWater() async -> Bool {
        guard let ml = Int(amountMl) else {
            state = .error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Количество должно быть числом"]))
            return false
        }

        state = .saving

        do {
            #if DEBUG
            print("[Network] WaterVM createWater")
            #endif
            try await service.createWaterEntry(amountMl: ml, date: nil)
            await cacheService?.remove("water_today")
            await cacheService?.remove("summary_today")
            await cacheService?.removeByPrefix("chart_summaries")
            await cacheService?.removeByPrefix("analytics_")
            progressRefreshState?.invalidate()

            do {
                let entries = try await service.getTodayWater()
                try? await cacheService?.set("water_today", entries, ttl: 300)
                state = .loaded(entries)
            } catch {
                if let cached: [WaterEntry] = try? await cacheService?.get("water_today", ignoreTTL: true) {
                    state = .loaded(cached)
                } else {
                    state = .loaded([])
                }
            }

            clearForm()
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

    @discardableResult
    func deleteWater(id: String) async -> Bool {
        do {
            #if DEBUG
            print("[Network] WaterVM deleteWater")
            #endif
            try await service.deleteWaterEntry(id: id, date: nil)
            await cacheService?.remove("water_today")
            await cacheService?.remove("summary_today")
            await cacheService?.removeByPrefix("chart_summaries")
            await cacheService?.removeByPrefix("analytics_")
            progressRefreshState?.invalidate()

            do {
                let entries = try await service.getTodayWater()
                try? await cacheService?.set("water_today", entries, ttl: 300)
                state = .loaded(entries)
            } catch {
                if let cached: [WaterEntry] = try? await cacheService?.get("water_today", ignoreTTL: true) {
                    state = .loaded(cached)
                } else {
                    state = .loaded([])
                }
            }

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

    private func clearForm() {
        amountMl = ""
    }
    
    func setPreviewState(_ newState: WaterState) {
        state = newState
    }
}
