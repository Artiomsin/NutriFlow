import Foundation
import Observation

@Observable
@MainActor
final class GoalsViewModel {
    var state: GoalsState = .idle

    @ObservationIgnored private let service: GoalsServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?

    init(coordinator: AppCoordinator, service: GoalsServiceProtocol) {
        print("GoalsViewModel init")
        self.coordinator = coordinator
        self.service = service
    }

    deinit { print("GoalsViewModel deinit") }

    func loadGoals() async {
        state = .loading
        do {
            let goals = try await service.getGoals()
            state = .loaded(goals)
        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator?.goToAuth()
            }
            state = .error(error)
        } catch {
            state = .error(error)
        }
    }
}
