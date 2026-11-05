import Foundation
import Observation

enum CategoryFoodsState {
    case idle
    case loading
    case loaded
    case error(AppError)
}

@Observable
@MainActor
final class CategoryFoodsViewModel {
    var state: CategoryFoodsState = .idle
    var foods: [CatalogFood] = []
    var isUpdating = false

    @ObservationIgnored private let category: FoodCategory
    @ObservationIgnored private let service: FoodServiceProtocol

    init(category: FoodCategory, service: FoodServiceProtocol) {
        self.category = category
        self.service = service
    }

    func load() async {
        state = .loading

        do {
            let groups = try await service.getFoods(
                categoryId: category.id,
                limit: 100,
                offset: 0
            )
            foods = groups.flatMap(\.foods)
            state = .loaded
        } catch {
            let mapped = ErrorMapper.map(error)
            state = mapped == .cancelled ? .loaded : .error(mapped)
        }
    }

    func assignSelectedFoods(
        _ foodIds: Set<String>,
        to categoryId: String?
    ) async -> Bool {
        guard !foodIds.isEmpty, !isUpdating else { return false }

        isUpdating = true
        defer { isUpdating = false }

        do {
            let response = try await service.bulkUpdateFoodCategory(
                foodIds: Array(foodIds),
                categoryId: categoryId
            )
            let updatedIDs = Set(response.foodIds)
            foods.removeAll { updatedIDs.contains($0.id) }
            return true
        } catch {
            let mapped = ErrorMapper.map(error)
            state = mapped == .cancelled ? .loaded : .error(mapped)
            return false
        }
    }
}
