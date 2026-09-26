import Foundation
import Observation
import UIKit

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

    var categories: [FoodCategory] = []
    var categoriesError: AppError?
    var selectedCategory: FoodCategory?

    var popularFoods: [CatalogFood] = []
    var isLoadingPopular = false
    var popularError: AppError?

    @ObservationIgnored private let service: FoodServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let analyticsTracker: AnalyticsTracking?
    @ObservationIgnored private let prefsStore = PreferencesStore.shared
    @ObservationIgnored private var uploadedImageUrl: String?

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

    var gramsValue: Double? {
        UnitConversion.parseDecimal(grams)
    }

    var caloriesValue: Double? {
        UnitConversion.parseDecimal(calories)
    }

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (gramsValue ?? 0) > 0
            && (caloriesValue ?? 0) > 0
    }

    var isBusy: Bool {
        switch state {
        case .saving, .uploading: return true
        default: return false
        }
    }

    init(service: FoodServiceProtocol, coordinator: AppCoordinator?, analyticsTracker: AnalyticsTracking? = nil) {
        print("AddFoodViewModel init")
        self.service = service
        self.coordinator = coordinator
        self.analyticsTracker = analyticsTracker
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
    func createEntry(imageData: Data? = nil) async -> Bool {
        guard !isBusy else { return false }

        let gramsInt = toGrams(grams) ?? 0
        guard gramsInt > 0 else {
            state = .error(.validation(message: "Enter a weight greater than 0."))
            return false
        }
        guard let caloriesValue = UnitConversion.parseDecimal(calories), caloriesValue > 0 else {
            state = .error(.validation(message: "Enter calories greater than 0."))
            return false
        }
        let caloriesInt = Int(UnitConversion.energyToKcal(caloriesValue, preferred: prefsStore.preferredUnits).rounded())

        state = .uploading

        var imageUrl: String? = uploadedImageUrl
        if imageUrl == nil, let data = imageData {
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

            clearForm()
            state = .idle
            return true
        } catch {
            handle(error)
            return false
        }
    }

    func clearError() {
        if case .error = state {
            state = .idle
        }
    }

    /// Called when the user picks a different photo, so a retry reuses the existing
    /// upload only while it still matches the image on screen.
    func invalidateUploadedImage() {
        uploadedImageUrl = nil
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
    }
    
    private func handle(_ error: Error) {
        let appError = ErrorMapper.map(error)
        if appError == .unauthorized {
            coordinator?.goToAuth()
        }
        state = appError == .cancelled ? .idle : .error(appError)
    }
    
}
