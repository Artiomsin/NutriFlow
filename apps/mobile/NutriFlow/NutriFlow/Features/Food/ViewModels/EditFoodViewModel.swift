import Foundation
import Observation
import UIKit
import SwiftUI
import PhotosUI

@Observable
final class EditFoodViewModel {
    let entry: FoodEntry
    private let foodService: FoodServiceProtocol
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    private let prefsStore = PreferencesStore.shared

    var name: String
    var calories: String
    var protein: String
    var fat: String
    var carbs: String
    var grams: String

    var photosItem: PhotosPickerItem?
    var selectedImageData: Data?
    var selectedImage: UIImage? { selectedImageData.flatMap { UIImage(data: $0) } }
    var isLoading = false
    var categories: [FoodCategory] = []
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

    init(entry: FoodEntry, foodService: FoodServiceProtocol, coordinator: AppCoordinator? = nil) {
        self.entry = entry
        self.foodService = foodService
        self.coordinator = coordinator
        self.name = entry.name
        let prefs = PreferencesStore.shared.preferredUnits
        self.calories = "\(UnitConversion.formatEnergyValue(kcal: entry.calories, preferred: prefs))"
        self.protein = entry.protein.map { UnitConversion.macroDisplay(grams: Double($0), preferred: prefs) } ?? ""
        self.fat = entry.fat.map { UnitConversion.macroDisplay(grams: Double($0), preferred: prefs) } ?? ""
        self.carbs = entry.carbs.map { UnitConversion.macroDisplay(grams: Double($0), preferred: prefs) } ?? ""
        self.grams = entry.grams.map {
            let unit = UnitConversion.displayUnit(for: entry.unit, preferred: prefs)
            let value = UnitConversion.displayValue(fromGrams: Double($0), baseUnit: entry.unit, preferred: prefs)
            return UnitConversion.formatDisplayValue(value, displayUnit: unit)
        } ?? ""
        self.selectedCategoryName = entry.categoryName
    }

    private func toGrams(_ value: String) -> Double? {
        guard let val = UnitConversion.parseDecimal(value), val > 0 else { return nil }
        return UnitConversion.grams(fromDisplay: val, baseUnit: entry.unit, preferred: prefsStore.preferredUnits)
    }

    func loadCategories() async {
        guard categories.isEmpty else { return }
        categories = (try? await foodService.getCategories()) ?? []
    }

    func save() async -> Bool {
        if isCatalogFood && nameNotChanged {
            showNameWarning = true
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            var imageUrl: String?
            if let data = selectedImageData {
                imageUrl = try await foodService.uploadImage(data)
            }

            let gramsInG = toGrams(grams).map { Int($0.rounded()) }
            try await foodService.updateFoodEntry(
                id: entry.id,
                name: name.trimmingCharacters(in: .whitespaces),
                calories: UnitConversion.parseDecimal(calories).flatMap {
                    Int(UnitConversion.energyToKcal($0, preferred: prefsStore.preferredUnits).rounded())
                },
                protein: UnitConversion.macroGrams(fromDisplay: protein, preferred: prefsStore.preferredUnits),
                fat: UnitConversion.macroGrams(fromDisplay: fat, preferred: prefsStore.preferredUnits),
                carbs: UnitConversion.macroGrams(fromDisplay: carbs, preferred: prefsStore.preferredUnits),
                grams: gramsInG,
                foodId: nil,
                date: nil,
                imageUrl: imageUrl,
                categoryName: selectedCategoryName
            )

            return true
        } catch let error as APIError {
            if case .unauthorized = error {
                await coordinator?.goToAuth()
            }
            return false
        } catch {
            return false
        }
    }

    func loadImage(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            selectedImageData = ImageCompressor.optimizedJPEGData(data)
        }
    }

    func recalculateMacros(from gramsString: String) {
        guard let baseGrams = entry.grams, baseGrams > 0 else { return }
        guard let newGrams = toGrams(gramsString), newGrams > 0 else { return }
        let ratio = newGrams / Double(baseGrams)
        let prefs = prefsStore.preferredUnits
        calories = "\(UnitConversion.formatEnergyValue(kcal: Int((Double(entry.calories) * ratio).rounded()), preferred: prefs))"
        if let p = entry.protein { protein = UnitConversion.macroDisplay(grams: Double(p) * ratio, preferred: prefs) }
        if let f = entry.fat { fat = UnitConversion.macroDisplay(grams: Double(f) * ratio, preferred: prefs) }
        if let c = entry.carbs { carbs = UnitConversion.macroDisplay(grams: Double(c) * ratio, preferred: prefs) }
    }
}
