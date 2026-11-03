import Foundation
import Observation
import UIKit
import SwiftUI
import PhotosUI

@Observable
@MainActor
final class EditFoodViewModel {
    let entry: FoodEntry
    private let foodService: FoodServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let analyticsTracker: AnalyticsTracking?
    private let prefsStore = PreferencesStore.shared
    @ObservationIgnored private var uploadedImageUrl: String?

    var name: String
    var calories: String
    var protein: String
    var fat: String
    var carbs: String
    var grams: String
    var fieldErrors = FormFieldErrors()

    var photosItem: PhotosPickerItem?
    var selectedImageData: Data?
    var selectedImage: UIImage? { selectedImageData.flatMap { UIImage(data: $0) } }
    var isLoading = false
    var error: AppError?
    var categories: [FoodCategory] = []
    var categoriesError: AppError?
    var selectedCategoryName: String?
    var showNameWarning = false

    var source: String? { entry.foodSource }

    var isCatalogFood: Bool {
        guard let source else { return false }
        return source != "user"
    }

    var nameNotChanged: Bool {
        name.trimmingCharacters(in: .whitespaces) == entry.name
    }

    var displayUnit: String {
        UnitConversion.displayUnit(for: entry.unit, preferred: prefsStore.preferredUnits)
    }

    var gramsLabel: String {
        "Weight (\(displayUnit))"
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

    init(entry: FoodEntry, foodService: FoodServiceProtocol, coordinator: AppCoordinator? = nil, analyticsTracker: AnalyticsTracking? = nil) {
        self.entry = entry
        self.foodService = foodService
        self.coordinator = coordinator
        self.analyticsTracker = analyticsTracker
        self.name = entry.name
        let prefs = PreferencesStore.shared.preferredUnits
        self.calories = UnitConversion.formatEnergyValueText(kcal: entry.calories, preferred: prefs)
        self.protein = entry.protein.map { UnitConversion.macroDisplay(grams: $0, preferred: prefs) } ?? ""
        self.fat = entry.fat.map { UnitConversion.macroDisplay(grams: $0, preferred: prefs) } ?? ""
        self.carbs = entry.carbs.map { UnitConversion.macroDisplay(grams: $0, preferred: prefs) } ?? ""
        self.grams = entry.grams.map {
            let unit = UnitConversion.displayUnit(for: entry.unit, preferred: prefs)
            let value = UnitConversion.displayValue(fromGrams: $0, baseUnit: entry.unit, preferred: prefs)
            return UnitConversion.formatDisplayValue(value, displayUnit: unit)
        } ?? ""
        self.selectedCategoryName = entry.categoryName
    }

    func trackScreenView() {
        analyticsTracker?.track(.screenView(screen: "edit_food"))
    }

    private var foodDisplayFractionDigits: Int {
        prefsStore.preferredUnits.weight == .imperial ? 3 : UnitConversion.nutritionFractionDigits
    }

    private let portionInputFractionDigits = UnitConversion.portionFractionDigits

    private var originalGramsText: String {
        guard let grams = entry.grams else { return "" }
        let value = UnitConversion.displayValue(
            fromGrams: grams,
            baseUnit: entry.unit,
            preferred: prefsStore.preferredUnits
        )
        return UnitConversion.formatDisplayValue(value, displayUnit: displayUnit)
    }

    private func toGrams(_ value: String) -> Double? {
        let valueText = value.trimmingCharacters(in: .whitespacesAndNewlines)

        // Metric gram display intentionally uses one decimal. Keep the persisted
        // value unless the person actually changes the displayed amount.
        if valueText == originalGramsText, let grams = entry.grams {
            return grams
        }

        guard UnitConversion.isValidNutritionInput(
            valueText,
            maximumFractionDigits: portionInputFractionDigits
        ),
              let displayValue = UnitConversion.parseDecimal(valueText),
              displayValue > 0 else {
            return nil
        }

        return UnitConversion.grams(
            fromDisplay: displayValue,
            baseUnit: entry.unit,
            preferred: prefsStore.preferredUnits
        )
    }

    private func validatedAmount(
        _ text: String,
        field: String,
        required: Bool,
        requiresPositiveValue: Bool = true,
        maximumFractionDigits: Int = UnitConversion.nutritionFractionDigits
    ) -> Double? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.isEmpty else {
            if required {
                fieldErrors.set(FormErrorMapper.message(for: FieldErrorCode.required.rawValue), for: field)
            }
            return nil
        }

        guard UnitConversion.isValidNutritionInput(value, maximumFractionDigits: maximumFractionDigits),
              let decimal = UnitConversion.parseDecimal(value),
              requiresPositiveValue ? decimal > 0 : decimal >= 0 else {
            fieldErrors.set("Enter a valid number with the supported precision.", for: field)
            return nil
        }

        return decimal
    }

    func loadCategories() async {
        guard categories.isEmpty else { return }
        categoriesError = nil
        do {
            categories = try await foodService.getCategories()
        } catch {
            let mapped = ErrorMapper.map(error)
            categoriesError = mapped == .cancelled ? nil : mapped
        }
    }

    func retryCategories() {
        Task { await loadCategories() }
    }

    func retrySave() {
        Task { _ = await save() }
    }

    func clearFieldError(_ field: String) {
        let numericText: String? = switch field {
        case "grams": grams
        case "calories": calories
        case "protein": protein
        case "fat": fat
        case "carbs": carbs
        default: nil
        }

        if let numericText,
           !numericText.isEmpty,
           (!UnitConversion.isValidNutritionInput(
                numericText,
                maximumFractionDigits: field == "grams"
                    ? portionInputFractionDigits
                    : (field == "calories"
                        ? UnitConversion.nutritionFractionDigits
                        : foodDisplayFractionDigits)
            ) || (field == "grams" || field == "calories"
                ? (UnitConversion.parseDecimal(numericText) ?? 0) <= 0
                : (UnitConversion.parseDecimal(numericText) ?? 0) < 0)) {
            fieldErrors.set("Enter a valid number with the supported precision.", for: field)
        } else {
            fieldErrors.clear(field)
        }

        error = nil
    }

    func save() async -> Bool {
        guard !isLoading else { return false }

        if isCatalogFood && nameNotChanged {
            showNameWarning = true
            return false
        }

        fieldErrors.removeAll()

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fieldErrors.set(FormErrorMapper.message(for: FieldErrorCode.required.rawValue), for: "name")
        }

        let gramsInG = toGrams(grams)
        let caloriesValue = validatedAmount(calories, field: "calories", required: true)
        let proteinValue = validatedAmount(
            protein,
            field: "protein",
            required: false,
            requiresPositiveValue: false,
            maximumFractionDigits: foodDisplayFractionDigits
        )
        let fatValue = validatedAmount(
            fat,
            field: "fat",
            required: false,
            requiresPositiveValue: false,
            maximumFractionDigits: foodDisplayFractionDigits
        )
        let carbsValue = validatedAmount(
            carbs,
            field: "carbs",
            required: false,
            requiresPositiveValue: false,
            maximumFractionDigits: foodDisplayFractionDigits
        )

        if gramsInG == nil {
            _ = validatedAmount(grams, field: "grams", required: true)
        }

        guard fieldErrors.isEmpty,
              let gramsInG,
              let caloriesValue else {
            return false
        }

        error = nil
        isLoading = true
        defer { isLoading = false }

        do {
            var imageUrl: String? = uploadedImageUrl
            if imageUrl == nil, let data = selectedImageData {
                imageUrl = try await foodService.uploadImage(data)
                uploadedImageUrl = imageUrl
            }

            try await foodService.updateFoodEntry(
                id: entry.id,
                name: name.trimmingCharacters(in: .whitespaces),
                calories: UnitConversion.roundedForNutritionStorage(
                    UnitConversion.energyToKcal(caloriesValue, preferred: prefsStore.preferredUnits)
                ),
                protein: proteinValue.flatMap { _ in
                    UnitConversion.macroGrams(fromDisplay: protein, preferred: prefsStore.preferredUnits)
                        .map(UnitConversion.roundedForNutritionStorage)
                },
                fat: fatValue.flatMap { _ in
                    UnitConversion.macroGrams(fromDisplay: fat, preferred: prefsStore.preferredUnits)
                        .map(UnitConversion.roundedForNutritionStorage)
                },
                carbs: carbsValue.flatMap { _ in
                    UnitConversion.macroGrams(fromDisplay: carbs, preferred: prefsStore.preferredUnits)
                        .map(UnitConversion.roundedForNutritionStorage)
                },
                grams: gramsInG,
                unit: entry.unit,
                foodId: nil,
                date: nil,
                imageUrl: imageUrl,
                categoryName: selectedCategoryName
            )

            return true
        } catch {
            handle(error)
            return false
        }
    }

    private func handle(_ rawError: Error) {
        switch ErrorHandler.handle(
            rawError,
            supportedFields: ["name", "grams", "calories", "protein", "fat", "carbs"]
        ) {
        case .fieldErrors(let errors):
            fieldErrors = errors
            error = nil

        case .general(let appError):
            fieldErrors.removeAll()

            if appError == .unauthorized {
                coordinator?.goToAuth()
            }

            error = appError == .cancelled ? nil : appError
        }
    }

    func loadImage(_ item: PhotosPickerItem?) {
        uploadedImageUrl = nil
        guard let item else {
            selectedImageData = nil
            return
        }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            let optimizedImageData = await Task.detached(priority: .userInitiated) {
                ImageCompressor.optimizedJPEGData(data)
            }.value
            guard !Task.isCancelled else { return }
            selectedImageData = optimizedImageData
        }
    }

    /// Grams is the source of truth on this screen: calories and macros are derived
    /// from it in `recalculateMacros`, so converting grams alone keeps them consistent.
    func convertUnits(from old: PreferredUnits, to new: PreferredUnits) {
        guard old != new else { return }
        grams = UnitConversion.convertWeightText(grams, from: old, to: new)
    }

    func recalculateMacros(from gramsString: String) {
        guard let baseGrams = entry.grams, baseGrams > 0 else { return }
        guard let newGrams = toGrams(gramsString), newGrams > 0 else { return }
        let ratio = newGrams / baseGrams
        let prefs = prefsStore.preferredUnits
        calories = UnitConversion.formatEnergyValueText(kcal: entry.calories * ratio, preferred: prefs)
        if let p = entry.protein { protein = UnitConversion.macroDisplay(grams: p * ratio, preferred: prefs) }
        if let f = entry.fat { fat = UnitConversion.macroDisplay(grams: f * ratio, preferred: prefs) }
        if let c = entry.carbs { carbs = UnitConversion.macroDisplay(grams: c * ratio, preferred: prefs) }
    }
}
