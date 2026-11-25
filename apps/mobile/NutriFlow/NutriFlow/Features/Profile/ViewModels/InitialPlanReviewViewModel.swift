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

    init(
        coordinator: AppCoordinator,
        service: GoalsServiceProtocol
    ) {
        self.coordinator = coordinator
        self.service = service
    }

    func load(draft: GoalsPreviewDraftRequest) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            preview = try await service.previewDraft(draft)
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

    func retry(draft: GoalsPreviewDraftRequest) {
        Task { await load(draft: draft) }
    }
}
