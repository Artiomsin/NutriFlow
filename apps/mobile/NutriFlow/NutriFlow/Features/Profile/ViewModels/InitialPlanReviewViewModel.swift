import Foundation
import Observation

@Observable
@MainActor
final class InitialPlanReviewViewModel {
    var preview: GoalsPreview?
    var error: AppError?
    var isLoading = false

    @ObservationIgnored private let service: GoalsServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let cacheService: CacheService?

    init(
        coordinator: AppCoordinator,
        service: GoalsServiceProtocol,
        cacheService: CacheService? = nil
    ) {
        self.coordinator = coordinator
        self.service = service
        self.cacheService = cacheService
    }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let preview = try await service.getGoalsPreview()
            self.preview = preview
            try? await cacheService?.set("goals_preview", preview, ttl: 300)
        } catch is CancellationError {
            return
        } catch {
            let mapped = ErrorMapper.map(error)
            if mapped == .unauthorized {
                coordinator?.goToAuth()
            }
            self.error = mapped
        }
    }

    func retry() {
        Task { await load() }
    }
}
