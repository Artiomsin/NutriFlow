import Foundation
import Observation

@Observable
@MainActor
final class GoalsViewModel {
    var state: GoalsState = .idle

    @ObservationIgnored private let service: GoalsServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let cacheService: CacheService?

    init(coordinator: AppCoordinator, service: GoalsServiceProtocol, cacheService: CacheService? = nil) {
        print("GoalsViewModel init")
        self.coordinator = coordinator
        self.service = service
        self.cacheService = cacheService
    }

    deinit { print("GoalsViewModel deinit") }

    func loadGoals() async {
        if let cached: UserGoals = try? await cacheService?.get("goals") {
            state = .loaded(cached)
            return
        }

        state = .loading
        do {
            #if DEBUG
            print("[Network] GoalsVM loadGoals")
            #endif
            let goals = try await service.getGoals()
            try? await cacheService?.set("goals", goals, ttl: 1800)
            state = .loaded(goals)
        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator?.goToAuth()
            }
            if let cached: UserGoals = try? await cacheService?.get("goals", ignoreTTL: true) {
                state = .loaded(cached)
            } else {
                state = .error(error)
            }
        } catch {
            if let cached: UserGoals = try? await cacheService?.get("goals", ignoreTTL: true) {
                state = .loaded(cached)
            } else {
                state = .error(error)
            }
        }
    }
}
