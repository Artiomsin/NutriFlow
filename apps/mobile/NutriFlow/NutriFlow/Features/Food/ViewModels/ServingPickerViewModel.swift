import Foundation
import Observation

@Observable
@MainActor
final class ServingPickerViewModel {
    let food: CatalogFood
    let suggestedGrams: Double?
    let suggestedUnit: String?
    let todayFoodVM: TodayFoodViewModel

    var gramsText: String {
        didSet { pinnedGrams = nil }
    }
    var selectedServing: FoodServing?
    var isLoading = false
    var error: AppError?
    var fieldErrors = FormFieldErrors()

    private var pinnedGrams: Double?

    private let service: FoodServiceProtocol
    private let prefsStore = PreferencesStore.shared
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let analyticsTracker: AnalyticsTracking?

    init(food: CatalogFood, service: FoodServiceProtocol, todayFoodVM: TodayFoodViewModel, suggestedGrams: Double?, suggestedUnit: String?, coordinator: AppCoordinator?, analyticsTracker: AnalyticsTracking? = nil) {
        self.food = food
        self.service = service
        self.todayFoodVM = todayFoodVM
        self.suggestedGrams = suggestedGrams
        self.suggestedUnit = suggestedUnit
        self.coordinator = coordinator
        self.analyticsTracker = analyticsTracker

        if let suggestedGrams, suggestedGrams > 0 {
            self.gramsText = Self.gramsToDisplay(suggestedGrams, suggestedUnit: suggestedUnit)
        } else if let serving = food.servings?.first(where: { $0.grams > 0 }) {
            self.gramsText = Self.gramsToDisplay(serving.grams, suggestedUnit: suggestedUnit)
        } else {
            self.gramsText = Self.gramsToDisplay(Self.defaultGrams, suggestedUnit: suggestedUnit)
        }
    }

    private static let defaultGrams = 100.0

    func trackScreenView() {
        analyticsTracker?.track(.screenView(screen: "serving_picker"))
    }

    var baseUnit: String { suggestedUnit ?? "g" }

    private static func gramsToDisplay(_ grams: Double?, suggestedUnit: String?) -> String {
        guard let g = grams, g > 0 else { return "" }
        let prefs = PreferencesStore.shared.preferredUnits
        let unit = UnitConversion.displayUnit(for: suggestedUnit ?? "g", preferred: prefs)
        let value = UnitConversion.displayValue(fromGrams: g, baseUnit: suggestedUnit ?? "g", preferred: prefs)
        return UnitConversion.formatDisplayValue(value, displayUnit: unit)
    }

    var displayUnit: String {
        UnitConversion.displayUnit(for: baseUnit, preferred: prefsStore.preferredUnits)
    }

    func selectPreset(_ serving: FoodServing) {
        selectedServing = serving
        setText(gramsToDisplay(serving.grams), pinned: serving.grams)
    }

    func selectSuggested(_ grams: Double) {
        setText(gramsToDisplay(grams), pinned: grams)
    }

    private func setText(_ text: String, pinned: Double?) {
        gramsText = text
        pinnedGrams = pinned
    }

    var grams: Double {
        if let pinned = pinnedGrams { return pinned }
        guard UnitConversion.isValidNutritionInput(
            gramsText,
            maximumFractionDigits: UnitConversion.portionFractionDigits
        ),
              let value = UnitConversion.parseDecimal(gramsText),
              value > 0 else {
            if let serving = selectedServing { return serving.grams }
            return 100.0
        }
        return UnitConversion.grams(
            fromDisplay: value,
            baseUnit: baseUnit,
            preferred: prefsStore.preferredUnits
        )
    }

    var ratio: Double { grams / 100.0 }

    var isValid: Bool {
        if let pinned = pinnedGrams { return pinned > 0 }
        if let serving = selectedServing { return serving.grams > 0 }
        guard UnitConversion.isValidNutritionInput(
            gramsText,
            maximumFractionDigits: UnitConversion.portionFractionDigits
        ),
              let value = UnitConversion.parseDecimal(gramsText) else {
            return false
        }
        return value > 0
    }

    var calculatedCalories: Double { food.caloriesPer100g * ratio }
    var calculatedProtein: Double? { food.proteinPer100g.map { $0 * ratio } }
    var calculatedFat: Double? { food.fatPer100g.map { $0 * ratio } }
    var calculatedCarbs: Double? { food.carbsPer100g.map { $0 * ratio } }

    func gramsToDisplay(_ g: Double) -> String {
        let value = UnitConversion.displayValue(fromGrams: g, baseUnit: baseUnit, preferred: prefsStore.preferredUnits)
        return UnitConversion.formatDisplayValue(value, displayUnit: displayUnit)
    }

    func save() async -> Bool {
        guard !isLoading else { return false }
        fieldErrors.removeAll()
        error = nil
        guard isValid else {
            fieldErrors.set(
                "Enter a positive number with the supported precision.",
                for: "grams"
            )
            return false
        }

        isLoading = true

        let cal = UnitConversion.roundedForNutritionStorage(calculatedCalories)
        let prot = calculatedProtein.map(UnitConversion.roundedForNutritionStorage)
        let ft = calculatedFat.map(UnitConversion.roundedForNutritionStorage)
        let crb = calculatedCarbs.map(UnitConversion.roundedForNutritionStorage)

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
                categoryId: food.categoryId,
                createPersonalFood: false,
                updatePersonalFood: false,
                imageUrl: food.imageUrl,
                date: nil
            )

            await todayFoodVM.reloadAfterMutation()
            todayFoodVM.notifyDataMutated()
            isLoading = false
            return true
        } catch {
            handle(error)
            isLoading = false
            return false
        }
    }

    /// `gramsText` holds a display value while the canonical amount is derived from
    /// it on read, so a unit change mid-edit would silently reinterpret the amount.
    /// Calories and macros here are derived from `ratio`, so they follow along.
    func convertUnits(from old: PreferredUnits, to new: PreferredUnits) {
        guard old != new else { return }
        gramsText = UnitConversion.convertWeightText(gramsText, from: old, to: new, baseUnit: baseUnit)
    }

    func clearFieldError(_ field: String) {
        fieldErrors.clear(field)
        error = nil
    }

    func retrySave() {
        Task { _ = await save() }
    }

    private func handle(_ rawError: Error) {
        switch ErrorHandler.handle(
            rawError,
            supportedFields: ["name", "grams", "calories", "protein", "fat", "carbs"]
        ) {
        case .fieldErrors(let errors):
            // This screen has a single editable input. Nutrition values are
            // derived from grams, so their validation belongs under it.
            var mapped = FormFieldErrors()

            for field in ["grams", "calories", "protein", "fat", "carbs", "name"] {
                if let message = errors[field] {
                    mapped.set(message, for: "grams")
                    break
                }
            }

            fieldErrors = mapped
        case .general(let appError):
            if appError == .unauthorized {
                coordinator?.goToAuth()
            }
            error = appError == .cancelled ? nil : appError
        }
    }
}
