import Foundation
import Observation
import UIKit

enum AddFoodState {
    case idle
    case saving
    case uploading
    case error(Error)
}

@Observable
@MainActor
final class AddFoodViewModel {
    var state: AddFoodState = .idle

    var name: String = ""
    var grams: String = ""
    var calories: String = ""
    var protein: String = ""
    var fat: String = ""
    var carbs: String = ""

    var categories: [FoodCategory] = []
    var selectedCategory: FoodCategory?

    @ObservationIgnored private let service: FoodServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?

    init(service: FoodServiceProtocol, coordinator: AppCoordinator?) {
        print("AddFoodViewModel init")
        self.service = service
        self.coordinator = coordinator
    }

    deinit { print("AddFoodViewModel deinit") }

    func loadCategories() async {
        guard categories.isEmpty else { return }
        categories = (try? await service.getCategories()) ?? []
    }

    func createEntry(imageData: Data? = nil, actualGrams: Int? = nil, actualProtein: Int? = nil, actualFat: Int? = nil, actualCarbs: Int? = nil) async {
        let gramsInt = actualGrams ?? (Double(grams).map { Int($0.rounded()) } ?? 0)
        guard gramsInt > 0 else {
            state = .error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Граммы должны быть числом > 0"]))
            return
        }
        guard let caloriesInt = Int(calories) else {
            state = .error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Калории должны быть числом"]))
            return
        }

        state = .uploading

        var imageUrl: String? = nil
        if let data = imageData {
            do {
                imageUrl = try await service.uploadImage(data)
            } catch {
                state = .error(error)
                return
            }
        }

        state = .saving

        do {
            print("[Network] AddFoodVM createEntry")
            try await service.createFoodEntry(
                name: name,
                calories: caloriesInt,
                protein: actualProtein ?? (Double(protein).map { Int($0.rounded()) }),
                fat: actualFat ?? (Double(fat).map { Int($0.rounded()) }),
                carbs: actualCarbs ?? (Double(carbs).map { Int($0.rounded()) }),
                foodId: nil,
                grams: gramsInt,
                unit: "g",
                categoryName: selectedCategory?.name,
                imageUrl: imageUrl,
                date: nil
            )

            AnalyticsManager.shared.track(.foodAdded(name: name, calories: caloriesInt))

            clearForm()
            state = .idle
        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator?.goToAuth()
            }
            state = .error(error)
        } catch {
            state = .error(error)
        }
    }

    func addFromCatalog(food: CatalogFood, grams: Int) async {
        let ratio = Double(grams) / 100.0
        let cal = Int(Double(food.caloriesPer100g) * ratio)
        let prot = food.proteinPer100g.map { Int(Double($0) * ratio) }
        let ft = food.fatPer100g.map { Int(Double($0) * ratio) }
        let crb = food.carbsPer100g.map { Int(Double($0) * ratio) }

        state = .saving

        do {
            try await service.createFoodEntry(
                name: food.name,
                calories: cal,
                protein: prot,
                fat: ft,
                carbs: crb,
                foodId: food.id,
                grams: grams,
                unit: "g",
                categoryName: food.categoryName,
                imageUrl: food.imageUrl,
                date: nil
            )

            AnalyticsManager.shared.track(.foodAdded(name: food.name, calories: cal))

            state = .idle
        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator?.goToAuth()
            }
            state = .error(error)
        } catch {
            state = .error(error)
        }
    }

    func reset() {
        name = ""
        grams = ""
        calories = ""
        protein = ""
        fat = ""
        carbs = ""
        selectedCategory = nil
        state = .idle
    }

    private func clearForm() {
        name = ""
        grams = ""
        calories = ""
        protein = ""
        fat = ""
        carbs = ""
        selectedCategory = nil
    }
}
