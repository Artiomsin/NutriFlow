import Foundation
import Observation
import UIKit
import SwiftUI
import PhotosUI

enum AddFoodState {
    case idle
    case saving
    case uploading
    case error(AppError)
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
    var fieldErrors = FormFieldErrors()

    var categories: [FoodCategory] = []
    var categoriesError: AppError?
    var selectedCategory: FoodCategory?
    var photosItem: PhotosPickerItem?
    var selectedImageData: Data?

    var popularFoods: [CatalogFood] = []
    var isLoadingPopular = false
    var popularError: AppError?

    @ObservationIgnored private let service: FoodServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let analyticsTracker: AnalyticsTracking?
    @ObservationIgnored private let prefsStore = PreferencesStore.shared
    @ObservationIgnored private var uploadedImageUrl: String?
    @ObservationIgnored private let todayFoodVM: TodayFoodViewModel

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

    private var foodDisplayFractionDigits: Int {
        prefsStore.preferredUnits.weight == .imperial ? 3 : UnitConversion.nutritionFractionDigits
    }

    private func toGrams(_ text: String) -> Double? {
        let valueText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard UnitConversion.isValidNutritionInput(
            valueText,
            maximumFractionDigits: foodDisplayFractionDigits
        ),
              let value = UnitConversion.parseDecimal(valueText),
              value > 0 else {
            return nil
        }

        return UnitConversion.roundedForNutritionStorage(
            UnitConversion.grams(fromDisplay: value, baseUnit: "g", preferred: prefsStore.preferredUnits)
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

    var gramsValue: Double? {
        UnitConversion.parseDecimal(grams)
    }

    var caloriesValue: Double? {
        UnitConversion.parseDecimal(calories)
    }

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && UnitConversion.isValidNutritionInput(
                grams,
                maximumFractionDigits: foodDisplayFractionDigits
            )
            && (gramsValue ?? 0) > 0
            && UnitConversion.isValidNutritionInput(calories)
            && (caloriesValue ?? 0) > 0
    }

    var isBusy: Bool {
        switch state {
        case .saving, .uploading: return true
        default: return false
        }
    }

    init(service: FoodServiceProtocol, coordinator: AppCoordinator?, analyticsTracker: AnalyticsTracking? = nil, todayFoodVM: TodayFoodViewModel) {
        print("AddFoodViewModel init")
        self.service = service
        self.coordinator = coordinator
        self.analyticsTracker = analyticsTracker
        self.todayFoodVM = todayFoodVM
    }

    deinit { print("AddFoodViewModel deinit") }

    func trackScreenView() {
        analyticsTracker?.track(.screenView(screen: "add_food"))
    }

    func loadCategories() async {
        guard categories.isEmpty else { return }
        categoriesError = nil
        do {
            categories = try await service.getCategories()
        } catch {
            let mapped = ErrorMapper.map(error)
            categoriesError = mapped == .cancelled ? nil : mapped
        }
    }

    func retryCategories() {
        Task { await loadCategories() }
    }

    func loadPopular() async {
        guard !isLoadingPopular else { return }
        isLoadingPopular = true
        popularError = nil
        defer { isLoadingPopular = false }
        do {
            popularFoods = try await service.getPopularFood()
        } catch {
            let mapped = ErrorMapper.map(error)
            popularError = mapped == .cancelled ? nil : mapped
        }
    }

    func retryPopular() {
        Task { await loadPopular() }
    }

    /// Fields hold display-unit text while conversion to canonical happens at save
    /// time, so a unit change mid-edit would silently reinterpret what was typed.
    func convertUnits(from old: PreferredUnits, to new: PreferredUnits) {
        guard old != new else { return }
        grams = UnitConversion.convertWeightText(grams, from: old, to: new)
        calories = UnitConversion.convertEnergyText(calories, from: old, to: new)
        protein = UnitConversion.convertWeightText(protein, from: old, to: new)
        fat = UnitConversion.convertWeightText(fat, from: old, to: new)
        carbs = UnitConversion.convertWeightText(carbs, from: old, to: new)
    }

    @discardableResult
    func createEntry() async -> Bool {
        guard !isBusy else { return false }

        fieldErrors.removeAll()

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fieldErrors.set(
                FormErrorMapper.message(for: FieldErrorCode.required.rawValue),
                for: "name"
            )
        }

        let gramsValue = toGrams(grams)
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

        if gramsValue == nil {
            _ = validatedAmount(grams, field: "grams", required: true)
        }

        guard fieldErrors.isEmpty,
              let gramsValue,
              let caloriesValue else {
            state = .idle
            return false
        }

        let caloriesInKcal = UnitConversion.roundedForNutritionStorage(
            UnitConversion.energyToKcal(caloriesValue, preferred: prefsStore.preferredUnits)
        )

        state = .uploading

        var imageUrl: String? = uploadedImageUrl
        if imageUrl == nil, let data = selectedImageData {
            do {
                imageUrl = try await service.uploadImage(data)
                uploadedImageUrl = imageUrl
            } catch {
                handle(error)
                return false
            }
        }

        state = .saving

        do {
            print("[Network] AddFoodVM createEntry")
            try await service.createFoodEntry(
                name: name,
                calories: caloriesInKcal,
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
                foodId: nil,
                grams: gramsValue,
                unit: "g",
                categoryName: selectedCategory?.name,
                imageUrl: imageUrl,
                date: nil
            )

            await todayFoodVM.reloadAfterMutation()
            todayFoodVM.notifyDataMutated()

            clearForm()
            state = .idle
            return true
        } catch {
            handle(error)
            return false
        }
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
                maximumFractionDigits: field == "calories"
                    ? UnitConversion.nutritionFractionDigits
                    : foodDisplayFractionDigits
            ) || (field == "grams" || field == "calories"
                ? (UnitConversion.parseDecimal(numericText) ?? 0) <= 0
                : (UnitConversion.parseDecimal(numericText) ?? 0) < 0)) {
            fieldErrors.set("Enter a valid number with the supported precision.", for: field)
        } else {
            fieldErrors.clear(field)
        }

        if case .error = state {
            state = .idle
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
                ImageCompressor.optimizedJPEGData(
                    data,
                    maxDimension: 800,
                    quality: 0.8
                )
            }.value
            guard !Task.isCancelled else { return }
            selectedImageData = optimizedImageData
        }
    }

    private func clearForm() {
        name = ""
        grams = ""
        calories = ""
        protein = ""
        fat = ""
        carbs = ""
        selectedCategory = nil
        uploadedImageUrl = nil
        photosItem = nil
        selectedImageData = nil
    }
    
    private func handle(_ error: Error) {
        switch ErrorHandler.handle(
            error,
            supportedFields: ["name", "grams", "calories", "protein", "fat", "carbs"]
        ) {
        case .fieldErrors(let errors):
            fieldErrors = errors
            state = .idle

        case .general(let appError):
            fieldErrors.removeAll()

            if appError == .unauthorized {
                coordinator?.goToAuth()
            }

            state = appError == .cancelled ? .idle : .error(appError)
        }
    }
    
}
