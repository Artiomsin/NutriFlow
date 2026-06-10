import Foundation
import Observation

@Observable
@MainActor
final class GoalsViewModel {
    var state: GoalsState = .idle

    @ObservationIgnored private let service: GoalsServiceProtocol

    init(service: GoalsServiceProtocol) {
        self.service = service
    }

    func loadGoals() async {
        state = .loading
        do {
            let goals = try await service.getGoals()
            state = .loaded(goals)
        } catch {
            state = .error(error)
        }
    }
}
