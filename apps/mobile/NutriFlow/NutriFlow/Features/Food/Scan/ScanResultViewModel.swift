import Foundation
import Observation
import SwiftUI

struct EditableScanFood: Identifiable, Sendable {
    enum MacroField: Sendable {
        case protein
        case fat
        case carbs
    }

    let id = UUID()
    let source: FoodAnalysisItem

    var isSelected = true
    var nameText: String
    var gramsText: String
    var categoryText: String
    var caloriesText: String
    var proteinText: String
    var fatText: String
    var carbsText: String

    init(_ item: FoodAnalysisItem, preferred: PreferredUnits) {
        self.source = item

        let grams = item.grams ?? 100
        let baseUnit = item.unit ?? "g"
        let unit = UnitConversion.displayUnit(for: baseUnit, preferred: preferred)
        let value = UnitConversion.displayValue(
            fromGrams: Double(grams),
            baseUnit: baseUnit,
            preferred: preferred
        )

        self.nameText = item.name ?? "Unknown food"
        self.gramsText = UnitConversion.formatDisplayValue(value, displayUnit: unit)
        self.categoryText = item.category ?? ""

        let baseCalories = item.bestCalories ?? item.calories ?? 0
        self.caloriesText = "\(UnitConversion.formatEnergyValue(kcal: Int(baseCalories.rounded()), preferred: preferred))"
        self.proteinText = Self.macroText(item.protein, preferred: preferred)
        self.fatText = Self.macroText(item.fat, preferred: preferred)
        self.carbsText = Self.macroText(item.carbs, preferred: preferred)
    }

    var name: String {
        let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? (source.name ?? "Unknown food") : trimmed
    }

    var categoryName: String? { categoryText.isEmpty ? nil : categoryText }

    var imageURL: URL? {
        source.imageUrl.flatMap { URL(string: $0) }
    }

    var baseUnit: String { source.unit ?? "g" }

    // MARK: - Canonical values (pure functions, explicit units)

    var baseGrams: Int { source.grams ?? 100 }
    var baseCalories: Double { source.bestCalories ?? source.calories ?? 0 }

    func gramsDouble(preferred: PreferredUnits) -> Double {
        UnitConversion.grams(
            fromText: gramsText,
            baseUnit: baseUnit,
            fallback: Double(baseGrams),
            preferred: preferred
        )
    }

    func grams(preferred: PreferredUnits) -> Int {
        Int(gramsDouble(preferred: preferred).rounded())
    }

    func ratio(preferred: PreferredUnits) -> Double {
        gramsDouble(preferred: preferred) / Double(baseGrams)
    }

    func calories(preferred: PreferredUnits) -> Int {
        guard let value = UnitConversion.parseDecimal(caloriesText) else { return Int(baseCalories.rounded()) }
        return Int(UnitConversion.energyToKcal(value, preferred: preferred).rounded())
    }

    func protein(preferred: PreferredUnits) -> Int? {
        UnitConversion.macroGrams(fromDisplay: proteinText, preferred: preferred)
    }

    func fat(preferred: PreferredUnits) -> Int? {
        UnitConversion.macroGrams(fromDisplay: fatText, preferred: preferred)
    }

    func carbs(preferred: PreferredUnits) -> Int? {
        UnitConversion.macroGrams(fromDisplay: carbsText, preferred: preferred)
    }

    // MARK: - Recalculation (pure, same as EditFoodView)

    mutating func recalculateMacros(preferred: PreferredUnits) {
        guard baseGrams > 0 else { return }
        let ratioValue = ratio(preferred: preferred)

        caloriesText = "\(UnitConversion.formatEnergyValue(kcal: Int((baseCalories * ratioValue).rounded()), preferred: preferred))"
        if let base = source.protein {
            proteinText = Self.macroText(base * ratioValue, preferred: preferred)
        }
        if let base = source.fat {
            fatText = Self.macroText(base * ratioValue, preferred: preferred)
        }
        if let base = source.carbs {
            carbsText = Self.macroText(base * ratioValue, preferred: preferred)
        }
    }

    private static func macroText(_ grams: Double?, preferred: PreferredUnits) -> String {
        guard let grams else { return "" }
        return UnitConversion.macroDisplay(grams: grams, preferred: preferred)
    }
}

@Observable
@MainActor
final class ScanResultViewModel {

    var items: [EditableScanFood]

    var isLoading = false
    var errorMessage: String?
    var categories: [FoodCategory] = []

    private let prefsStore: PreferencesStore
    private let service: FoodServiceProtocol
    private let todayFoodVM: TodayFoodViewModel
    private let imageData: Data?
    @ObservationIgnored private weak var coordinator: AppCoordinator?

    var preferredUnits: PreferredUnits { prefsStore.preferredUnits }

    var previewImage: UIImage? {
        guard let imageData else { return nil }
        return UIImage(data: imageData)
    }

    init(
        items: [FoodAnalysisItem],
        imageData: Data?,
        service: FoodServiceProtocol,
        todayFoodVM: TodayFoodViewModel,
        coordinator: AppCoordinator?,
        prefsStore: PreferencesStore = PreferencesStore.shared
    ) {
        self.items = items.map { EditableScanFood($0, preferred: prefsStore.preferredUnits) }
        self.imageData = imageData
        self.service = service
        self.todayFoodVM = todayFoodVM
        self.coordinator = coordinator
        self.prefsStore = prefsStore
    }

    var selectedItems: [EditableScanFood] {
        items.filter(\.isSelected)
    }

    var totalCalories: Double {
        selectedItems.map { Double($0.calories(preferred: preferredUnits)) }.reduce(0, +)
    }

    var totalGrams: Int {
        selectedItems.map { $0.grams(preferred: preferredUnits) }.reduce(0, +)
    }

    var totalCaloriesText: String {
        UnitConversion.formatEnergy(
            kcal: Int(totalCalories.rounded()),
            preferred: preferredUnits
        )
    }

    var totalGramsText: String {
        UnitConversion.formatMacro(grams: totalGrams, preferred: preferredUnits)
    }

    func updateName(id: UUID, _ text: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].nameText = text
    }

    func updateCaloriesText(id: UUID, _ text: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].caloriesText = text
    }

    func updateMacroText(id: UUID, field: EditableScanFood.MacroField, _ text: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        switch field {
        case .protein:
            items[index].proteinText = text
        case .fat:
            items[index].fatText = text
        case .carbs:
            items[index].carbsText = text
        }
    }

    func updateGramsText(id: UUID, _ text: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].gramsText = text
        items[index].recalculateMacros(preferred: preferredUnits)
    }

    func toggle(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isSelected.toggle()
    }

    func setCategory(id: UUID, _ category: String?) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].categoryText = category ?? ""
    }

    func loadCategories() async {
        guard categories.isEmpty else { return }
        categories = (try? await service.getCategories()) ?? []
    }

    func addToDiary() async -> Bool {
        let entries = selectedItems
        guard !entries.isEmpty else { return false }

        isLoading = true
        errorMessage = nil

        do {
            var imageUrl: String? = nil
            if let imageData {
                let optimized = ImageCompressor.optimizedJPEGData(imageData)
                if let optimized {
                    do {
                        imageUrl = try await service.uploadImage(optimized)
                        print("[ScanVM] uploaded scan photo: \(optimized.count / 1024) KB → \(imageUrl ?? "nil")")
                    } catch {
                        print("[ScanVM] photo upload failed, continuing without image: \(error.localizedDescription)")
                    }
                }
            }

            for item in entries {
                try await service.createFoodEntry(
                    name: item.name,
                    calories: item.calories(preferred: preferredUnits),
                    protein: item.protein(preferred: preferredUnits),
                    fat: item.fat(preferred: preferredUnits),
                    carbs: item.carbs(preferred: preferredUnits),
                    foodId: item.source.foodId,
                    grams: item.grams(preferred: preferredUnits),
                    unit: item.baseUnit,
                    categoryName: item.categoryName,
                    imageUrl: imageUrl,
                    date: nil
                )

                AnalyticsManager.shared.track(.foodAdded(name: item.name, calories: item.calories(preferred: preferredUnits)))
            }

            await todayFoodVM.reloadAfterAdd()

            isLoading = false
            return true

        } catch let error as APIError {
            if case .unauthorized = error {
                coordinator?.goToAuth()
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