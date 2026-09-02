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

    var popularFoods: [CatalogFood] = []
    var isLoadingPopular = false

    @ObservationIgnored private let service: FoodServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let prefsStore = PreferencesStore.shared

    var gramsLabel: String {
        prefsStore.preferredUnits.weight == .imperial ? "Ounces" : "Grams"
    }

    var caloriesLabel: String {
        "Calories (\(UnitConversion.formatEnergyUnit(preferred: prefsStore.preferredUnits)))"
    }

    var macroUnit: String {
        prefsStore.preferredUnits.weight == .imperial ? "oz" : "g"
    }

    var proteinLabel: String { "Protein (\(macroUnit))" }
    var fatLabel: String { "Fat (\(macroUnit))" }
    var carbsLabel: String { "Carbs (\(macroUnit))" }

    private func toGrams(_ text: String) -> Int? {
        guard let value = UnitConversion.parseDecimal(text), value > 0 else { return nil }
        return Int(UnitConversion.grams(fromDisplay: value, baseUnit: "g", preferred: prefsStore.preferredUnits).rounded())
    }

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

    func loadPopular() async {
        guard !isLoadingPopular else { return }
        isLoadingPopular = true
        defer { isLoadingPopular = false }
        popularFoods = ((try? await service.getPopularFood()) ?? [])
    }

    func createEntry(imageData: Data? = nil) async {
        let gramsInt = toGrams(grams) ?? 0
        guard gramsInt > 0 else {
            state = .error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Граммы должны быть числом > 0"]))
            return
        }
        guard let caloriesValue = UnitConversion.parseDecimal(calories) else {
            state = .error(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Калории должны быть числом"]))
            return
        }
        let caloriesInt = Int(UnitConversion.energyToKcal(caloriesValue, preferred: prefsStore.preferredUnits).rounded())

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
                protein: UnitConversion.macroGrams(fromDisplay: protein, preferred: prefsStore.preferredUnits),
                fat: UnitConversion.macroGrams(fromDisplay: fat, preferred: prefsStore.preferredUnits),
                carbs: UnitConversion.macroGrams(fromDisplay: carbs, preferred: prefsStore.preferredUnits),
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
