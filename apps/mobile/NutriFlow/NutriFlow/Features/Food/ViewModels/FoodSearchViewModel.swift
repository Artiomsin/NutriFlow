import Foundation
import Observation

enum FoodSearchState {
    case idle
    case searching
    case results([CatalogFood])
    case error(Error)
}

@Observable
@MainActor
final class FoodSearchViewModel {
    var state: FoodSearchState = .idle
    var query: String = ""
    var isSearching: Bool = false
    var suggestedGrams: Int?
    var suggestedUnit: String?
    var isLoadMore: Bool = false
    var hasMore: Bool = true
    var loadMoreError: Bool = false

    @ObservationIgnored private let service: FoodServiceProtocol
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var loadMoreTask: Task<Void, Never>?
    @ObservationIgnored private var offset: Int = 0
    @ObservationIgnored private let pageSize: Int = 20
    @ObservationIgnored private var selectionInFlight: Set<String> = []

    init(service: FoodServiceProtocol) {
        print("FoodSearchViewModel init")
        self.service = service
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
            isSearching = false
            suggestedGrams = nil
            suggestedUnit = nil
            return
        }

        isSearching = true
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
                isSearching = false
            } catch {
                guard !Task.isCancelled else { return }
                state = .error(error)
                isSearching = false
            }
        }
    }

    func loadMore() {
        guard hasMore, !isSearching, !isLoadMore else { return }
        guard case .results(let current) = state, !current.isEmpty else { return }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isLoadMore = true
        loadMoreError = false
        let nextOffset = offset + pageSize
        print("[Network] FoodSearchVM loadMore: query=\(trimmed) offset=\(nextOffset) limit=\(pageSize)")
        loadMoreTask = Task { [weak self] in
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
                self.loadMoreError = true
            }
            self.isLoadMore = false
        }
    }

    // Отправка статистики выбора (только для локальных продуктов с id)
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
        loadMoreError = false
    }

    func reset() {
        query = ""
        state = .idle
        isSearching = false
        suggestedGrams = nil
        suggestedUnit = nil
        resetPagination()
        searchTask?.cancel()
        loadMoreTask?.cancel()
    }
}
