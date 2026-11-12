import Foundation
import Observation

enum CategoryFoodsState: Equatable {
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
    var isLoadingMore = false
    var hasMoreFoods = true

    @ObservationIgnored private let categoryID: String?
    @ObservationIgnored private let service: FoodServiceProtocol
    @ObservationIgnored private let pageSize = 100

    /// A smaller first page shortens the wait before real rows replace the
    /// skeletons; later pages fall back to `pageSize` while the user scrolls.
    @ObservationIgnored private let firstPageSize = 30
    @ObservationIgnored private var nextOffset = 0

    init(category: FoodCategory, service: FoodServiceProtocol) {
        self.categoryID = category.id
        self.service = service
    }

    init(categoryID: String?, service: FoodServiceProtocol) {
        self.categoryID = categoryID
        self.service = service
    }

    func load() async {
        state = .loading
        foods = []
        nextOffset = 0
        hasMoreFoods = true
        await loadNextPage()
    }

    func loadMoreIfNeeded(current food: CatalogFood) async {
        guard food.id == foods.last?.id else { return }
        await loadMore()
    }

    func loadMoreSystemFoods() async {
        await loadMore()
    }

    func loadMore() async {
        guard hasMoreFoods, !isLoadingMore else { return }
        await loadNextPage()
    }

    private func loadNextPage() async {
        guard hasMoreFoods, !isLoadingMore else { return }

        isLoadingMore = true

        do {
            let pageLimit = nextOffset == 0 ? firstPageSize : pageSize
            let groups = try await service.getFoods(
                categoryId: categoryID,
                personalOnly: categoryID == nil,
                limit: pageLimit,
                offset: nextOffset
            )

            let fetchedFoods = groups.flatMap(\.foods)

            nextOffset += fetchedFoods.count
            hasMoreFoods = fetchedFoods.count == pageLimit && nextOffset <= 10_000
            foods.append(contentsOf: fetchedFoods)

            isLoadingMore = false
            state = .loaded

        } catch {
            isLoadingMore = false
            hasMoreFoods = false
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

            if categoryID == nil {
                await load()
            } else {
                let updatedIDs = Set(response.foodIds)
                foods.removeAll { updatedIDs.contains($0.id) }
            }

            return true

        } catch {
            let mapped = ErrorMapper.map(error)
            state = mapped == .cancelled ? .loaded : .error(mapped)
            return false
        }
    }
}
