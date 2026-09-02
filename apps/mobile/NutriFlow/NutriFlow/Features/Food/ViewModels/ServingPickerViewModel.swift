import Foundation
import Observation

@Observable
final class ServingPickerViewModel {
    let food: CatalogFood
    let suggestedGrams: Int?
    let suggestedUnit: String?
    let todayFoodVM: TodayFoodViewModel

    var gramsText: String {
        didSet { pinnedGrams = nil }
    }
    var selectedServing: FoodServing?
    var isLoading = false
    var errorMessage: String?

    private var pinnedGrams: Int?

    private let service: FoodServiceProtocol
    private let prefsStore = PreferencesStore.shared
    @ObservationIgnored private weak var coordinator: AppCoordinator?

    init(food: CatalogFood, service: FoodServiceProtocol, todayFoodVM: TodayFoodViewModel, suggestedGrams: Int?, suggestedUnit: String?, coordinator: AppCoordinator?) {
        self.food = food
        self.service = service
        self.todayFoodVM = todayFoodVM
        self.suggestedGrams = suggestedGrams
        self.suggestedUnit = suggestedUnit
        self.coordinator = coordinator
        self.gramsText = Self.gramsToDisplay(suggestedGrams, suggestedUnit: suggestedUnit)
    }

    var baseUnit: String { suggestedUnit ?? "g" }

    private static func gramsToDisplay(_ grams: Int?, suggestedUnit: String?) -> String {
        guard let g = grams, g > 0 else { return "" }
        let prefs = PreferencesStore.shared.preferredUnits
        let unit = UnitConversion.displayUnit(for: suggestedUnit ?? "g", preferred: prefs)
        let value = UnitConversion.displayValue(fromGrams: Double(g), baseUnit: suggestedUnit ?? "g", preferred: prefs)
        return UnitConversion.formatDisplayValue(value, displayUnit: unit)
    }

    var displayUnit: String {
        UnitConversion.displayUnit(for: baseUnit, preferred: prefsStore.preferredUnits)
    }

    func selectPreset(_ serving: FoodServing) {
        selectedServing = serving
        setText(gramsToDisplay(serving.grams), pinned: serving.grams)
    }

    func selectSuggested(_ grams: Int) {
        setText(gramsToDisplay(grams), pinned: grams)
    }

    private func setText(_ text: String, pinned: Int?) {
        gramsText = text
        pinnedGrams = pinned
    }

    var grams: Int {
        if let pinned = pinnedGrams { return pinned }
        guard let value = UnitConversion.parseDecimal(gramsText), value > 0 else {
            if let serving = selectedServing { return serving.grams }
            return 100
        }
        return Int(UnitConversion.grams(fromDisplay: value, baseUnit: baseUnit, preferred: prefsStore.preferredUnits).rounded())
    }

    var ratio: Double { Double(grams) / 100.0 }

    var calculatedCalories: Int { Int(Double(food.caloriesPer100g) * ratio) }
    var calculatedProtein: Int { food.proteinPer100g.map { Int(Double($0) * ratio) } ?? 0 }
    var calculatedFat: Int { food.fatPer100g.map { Int(Double($0) * ratio) } ?? 0 }
    var calculatedCarbs: Int { food.carbsPer100g.map { Int(Double($0) * ratio) } ?? 0 }

    func gramsToDisplay(_ g: Int) -> String {
        let value = UnitConversion.displayValue(fromGrams: Double(g), baseUnit: baseUnit, preferred: prefsStore.preferredUnits)
        return UnitConversion.formatDisplayValue(value, displayUnit: displayUnit)
    }

    func save() async -> Bool {
        isLoading = true
        errorMessage = nil

        let cal = calculatedCalories
        let prot = food.proteinPer100g.map { Int(Double($0) * ratio) }
        let ft = food.fatPer100g.map { Int(Double($0) * ratio) }
        let crb = food.carbsPer100g.map { Int(Double($0) * ratio) }

        do {
            try await service.createFoodEntry(
                name: food.name,
                calories: cal,
                protein: prot,
                fat: ft,
                carbs: crb,
                foodId: food.id.isEmpty ? nil : food.id,
                grams: grams,
                unit: suggestedUnit ?? "g",
                categoryName: food.categoryName,
                imageUrl: food.imageUrl,
                date: nil
            )

            AnalyticsManager.shared.track(.foodAdded(name: food.name, calories: cal))

            await todayFoodVM.reloadAfterAdd()
            return true
        } catch let error as APIError {
            if case .unauthorized = error {
                await coordinator?.goToAuth()
            }
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
}
