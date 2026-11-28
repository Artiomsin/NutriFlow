import Foundation
import Observation

/// Owns the goal-progress API state independently of chart rendering.
/// A confirmed adjustment is applied by GoalsViewModel, which then invalidates this model's cache.
@Observable
@MainActor
final class GoalsProgressViewModel {
    var progress: GoalsProgress?
    var error: AppError?
    var isLoading = false
    var selectedDays = 14

    @ObservationIgnored private let service: GoalsServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let cacheService: CacheService?
    @ObservationIgnored private var loadGeneration = 0

    init(
        coordinator: AppCoordinator,
        service: GoalsServiceProtocol,
        cacheService: CacheService? = nil
    ) {
        self.coordinator = coordinator
        self.service = service
        self.cacheService = cacheService
    }

    func load(days: Int? = nil, forceRefresh: Bool = false) async {
        let period = Self.validatedDays(days ?? selectedDays)
        selectedDays = period
        let cacheKey = "goals_progress_\(period)"
        loadGeneration &+= 1
        let generation = loadGeneration

        if forceRefresh {
            await cacheService?.remove(cacheKey)
        } else if let cached: GoalsProgress = try? await cacheService?.get(cacheKey) {
            progress = cached
            error = nil
            return
        }

        isLoading = true
        defer {
            if generation == loadGeneration {
                isLoading = false
            }
        }

        do {
            let loaded = try await service.getGoalsProgress(days: period)
            guard generation == loadGeneration else { return }
            progress = loaded
            error = nil
            try? await cacheService?.set(cacheKey, loaded, ttl: 300)
        } catch is CancellationError {
            return
        } catch {
            guard generation == loadGeneration else { return }
            let mapped = ErrorMapper.map(error)
            if mapped == .unauthorized {
                coordinator?.goToAuth()
            }
            if let stale: GoalsProgress = try? await cacheService?.get(cacheKey, ignoreTTL: true) {
                progress = stale
                self.error = nil
            } else {
                self.error = mapped
            }
        }
    }

    func retry() {
        Task { await load(forceRefresh: true) }
    }

    func invalidate() async {
        await cacheService?.removeByPrefix("goals_progress_")
    }

    private static func validatedDays(_ days: Int) -> Int {
        switch days {
        case 7, 14, 30: days
        default: 14
        }
    }
}
