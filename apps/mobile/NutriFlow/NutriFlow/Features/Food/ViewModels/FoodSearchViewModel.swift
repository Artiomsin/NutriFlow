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

    @ObservationIgnored private let service: FoodServiceProtocol
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    init(service: FoodServiceProtocol) {
        print("FoodSearchViewModel init")
        self.service = service
    }

    deinit {
        print("FoodSearchViewModel deinit")
        searchTask?.cancel()
    }

    func search() {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            state = .idle
            isSearching = false
            suggestedGrams = nil
            return
        }

        isSearching = true
        state = .searching

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)

            guard !Task.isCancelled else { return }

            do {
                print("[Network] FoodSearchVM search: \(trimmed)")
                let response = try await service.searchFood(query: trimmed, limit: 20)
                guard !Task.isCancelled else { return }
                suggestedGrams = response.suggestedGrams
                suggestedUnit = response.suggestedUnit
                state = .results(response.foods)
                isSearching = false
            } catch {
                guard !Task.isCancelled else { return }
                state = .error(error)
                isSearching = false
            }
        }
    }

    func reset() {
        query = ""
        state = .idle
        isSearching = false
        suggestedGrams = nil
        suggestedUnit = nil
        searchTask?.cancel()
    }
}
