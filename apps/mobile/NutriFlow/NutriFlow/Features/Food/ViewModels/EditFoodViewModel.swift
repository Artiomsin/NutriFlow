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
    var selectedImage: UIImage?
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
        self.protein = entry.protein.map { Self.formatMacroInput($0, preferred: prefs) } ?? ""
        self.fat = entry.fat.map { Self.formatMacroInput($0, preferred: prefs) } ?? ""
        self.carbs = entry.carbs.map { Self.formatMacroInput($0, preferred: prefs) } ?? ""
        self.grams = entry.grams.map {
            let unit = UnitConversion.displayUnit(for: entry.unit, preferred: prefs)
            let value = UnitConversion.displayValue(fromGrams: Double($0), baseUnit: entry.unit, preferred: prefs)
            return UnitConversion.formatDisplayValue(value, displayUnit: unit)
        } ?? ""
        self.selectedCategoryName = entry.categoryName
    }

    private static func formatMacroInput(_ grams: Int, preferred: PreferredUnits) -> String {
        if preferred.weight == .imperial {
            return String(format: "%.2f", Double(grams) / UnitConversion.gramsPerOunce)
        }
        return "\(grams)"
    }

    private func toGrams(_ value: String) -> Double? {
        guard let val = Double(value.replacingOccurrences(of: ",", with: ".")), val > 0 else { return nil }
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
            if let image = selectedImage, let data = image.jpegData(compressionQuality: 0.8) {
                imageUrl = try await foodService.uploadImage(data)
            }

            let gramsInG = toGrams(grams).map { Int($0.rounded()) }
            try await foodService.updateFoodEntry(
                id: entry.id,
                name: name.trimmingCharacters(in: .whitespaces),
                calories: Double(calories.replacingOccurrences(of: ",", with: ".")).flatMap {
                    Int(UnitConversion.energyToKcal($0, preferred: prefsStore.preferredUnits).rounded())
                },
                protein: macroToGrams(protein),
                fat: macroToGrams(fat),
                carbs: macroToGrams(carbs),
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

    private func macroToGrams(_ value: String) -> Int? {
        guard let val = Double(value.replacingOccurrences(of: ",", with: ".")) else { return nil }
        if prefsStore.preferredUnits.weight == .imperial {
            return Int((val * UnitConversion.gramsPerOunce).rounded())
        }
        return Int(val.rounded())
    }

    func loadImage(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            guard let image = UIImage(data: data) else { return }
            selectedImage = image.preparingThumbnail(of: CGSize(width: 800, height: 800))
        }
    }

    func recalculateMacros(from gramsString: String) {
        guard let baseGrams = entry.grams, baseGrams > 0 else { return }
        guard let newGrams = toGrams(gramsString), newGrams > 0 else { return }
        let ratio = newGrams / Double(baseGrams)
        let prefs = prefsStore.preferredUnits
        calories = "\(UnitConversion.formatEnergyValue(kcal: Int((Double(entry.calories) * ratio).rounded()), preferred: prefs))"
        if let p = entry.protein { protein = Self.formatMacroInput(Int((Double(p) * ratio).rounded()), preferred: prefs) }
        if let f = entry.fat { fat = Self.formatMacroInput(Int((Double(f) * ratio).rounded()), preferred: prefs) }
        if let c = entry.carbs { carbs = Self.formatMacroInput(Int((Double(c) * ratio).rounded()), preferred: prefs) }
    }
}
