import Foundation
import Observation

enum FoodSearchState {
    case idle
    case searching
    case results([CatalogFood])
    case error(AppError)
}

@Observable
@MainActor
final class FoodSearchViewModel {
    var state: FoodSearchState = .idle
    var query: String = ""
    var suggestedGrams: Int?
    var suggestedUnit: String?
    var isLoadMore: Bool = false
    var hasMore: Bool = true
    var loadMoreError: AppError?

    @ObservationIgnored private let service: FoodServiceProtocol
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var loadMoreTask: Task<Void, Never>?
    @ObservationIgnored private var offset: Int = 0
    @ObservationIgnored private let pageSize: Int = 20
    @ObservationIgnored private var selectionInFlight: Set<String> = []
    @ObservationIgnored private let analyticsTracker: AnalyticsTracking?

    init(service: FoodServiceProtocol, analyticsTracker: AnalyticsTracking? = nil) {
        print("FoodSearchViewModel init")
        self.service = service
        self.analyticsTracker = analyticsTracker
    }

    func trackScreenView() {
        analyticsTracker?.track(.screenView(screen: "food_search"))
    }

    deinit {
        print("FoodSearchViewModel deinit")
        searchTask?.cancel()
        loadMoreTask?.cancel()
    }

    func search() {
        searchTask?.cancel()
        loadMoreTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            resetPagination()
            state = .idle
            suggestedGrams = nil
            suggestedUnit = nil
            return
        }

        state = .searching

        searchTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 300_000_000)

            guard !Task.isCancelled else { return }

            do {
                print("[Network] FoodSearchVM search: \(trimmed)")
                let response = try await service.searchFood(query: trimmed, limit: pageSize, offset: 0)
                guard !Task.isCancelled else { return }
                suggestedGrams = response.suggestedGrams
                suggestedUnit = response.suggestedUnit
                offset = response.offset
                hasMore = response.hasMore
                state = .results(response.foods)
            } catch {
                guard !Task.isCancelled else { return }
                handle(error)
            }
        }
    }

    func loadMore() {
        guard hasMore, !isLoadMore else { return }
        guard case .results(let current) = state, !current.isEmpty else { return }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isLoadMore = true
        loadMoreError = nil
        let nextOffset = offset + pageSize
        print("[Network] FoodSearchVM loadMore: query=\(trimmed) offset=\(nextOffset) limit=\(pageSize)")
        loadMoreTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let response = try await service.searchFood(query: trimmed, limit: pageSize, offset: nextOffset)
                guard !Task.isCancelled else { return }
                if case .results(let existing) = self.state {
                    var merged = existing
                    let known = Set(merged.map(\.stableId))
                    merged.append(contentsOf: response.foods.filter { !known.contains($0.stableId) })
                    self.state = .results(merged)
                }
                self.offset = response.offset
                self.hasMore = response.hasMore
            } catch {
                guard !Task.isCancelled else { return }
                self.loadMoreError = ErrorMapper.map(error)
            }
            self.isLoadMore = false
        }
    }

    // send selection stats (only for local products with id)
    func selectIfLocal(_ food: CatalogFood) {
        guard !food.id.isEmpty else { return }
        guard !selectionInFlight.contains(food.id) else { return }
        selectionInFlight.insert(food.id)
        Task { [weak self] in
            try? await self?.service.selectFood(id: food.id)
            self?.selectionInFlight.remove(food.id)
        }
    }

    private func resetPagination() {
        offset = 0
        hasMore = true
        isLoadMore = false
        loadMoreError = nil
    }

    func reset() {
        query = ""
        state = .idle
        suggestedGrams = nil
        suggestedUnit = nil
        resetPagination()
        searchTask?.cancel()
        loadMoreTask?.cancel()
    }
    
    private func handle(_ error: Error) {
        let appError = ErrorMapper.map(error)

        state = appError == .cancelled
            ? .idle
            : .error(appError)
    }
    
    func retry() {
        search()
    }
}
