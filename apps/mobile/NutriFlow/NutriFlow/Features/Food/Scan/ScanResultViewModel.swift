import Foundation
import Observation
import SwiftUI



struct EditableScanWater: Identifiable, Sendable {
    let id = UUID()
    var isSelected = true
    var amountMlText: String
    let confidence: Double?

    init(_ item: WaterAnalysisItem) {
        amountMlText = String(item.amountMl)
        confidence = item.confidence
    }

    var amountMl: Int? {
        Int(amountMlText).flatMap { (50...2_000).contains($0) ? $0 : nil }
    }
}

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
        self.caloriesText = UnitConversion.formatEnergyValue(kcal: baseCalories, preferred: preferred).formatted(.number.precision(.fractionLength(0...2)))
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
        source.imageUrl.flatMap(ImageURLResolver.resolve)
    }
    
    var baseUnit: String { source.unit ?? "g" }
    
    
    var baseGrams: Double { source.grams ?? 100 }
    var baseCalories: Double { source.bestCalories ?? source.calories ?? 0 }
    
    func gramsDouble(preferred: PreferredUnits) -> Double {
        UnitConversion.grams(
            fromText: gramsText,
            baseUnit: baseUnit,
            fallback: baseGrams,
            preferred: preferred
        )
    }
    
    func grams(preferred: PreferredUnits) -> Double {
        gramsDouble(preferred: preferred)
    }
    
    func ratio(preferred: PreferredUnits) -> Double {
        gramsDouble(preferred: preferred) / baseGrams
    }
    
    func calories(preferred: PreferredUnits) -> Double {
        guard let value = UnitConversion.parseDecimal(caloriesText) else { return baseCalories }
        return UnitConversion.energyToKcal(value, preferred: preferred)
    }
    
    func protein(preferred: PreferredUnits) -> Double? {
        UnitConversion.macroGrams(fromDisplay: proteinText, preferred: preferred)
    }
    
    func fat(preferred: PreferredUnits) -> Double? {
        UnitConversion.macroGrams(fromDisplay: fatText, preferred: preferred)
    }
    
    func carbs(preferred: PreferredUnits) -> Double? {
        UnitConversion.macroGrams(fromDisplay: carbsText, preferred: preferred)
    }
    
    
    mutating func recalculateMacros(preferred: PreferredUnits) {
        guard baseGrams > 0 else { return }
        let ratioValue = ratio(preferred: preferred)
        
        caloriesText = UnitConversion.formatEnergyValue(kcal: baseCalories * ratioValue, preferred: preferred).formatted(.number.precision(.fractionLength(0...2)))
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

enum EditableScanResultItem: Identifiable, Sendable {
    case food(EditableScanFood)
    case water(EditableScanWater)

    var id: UUID {
        switch self {
        case .food(let item): item.id
        case .water(let item): item.id
        }
    }

    var isSelected: Bool {
        get {
            switch self {
            case .food(let item): item.isSelected
            case .water(let item): item.isSelected
            }
        }
        set {
            switch self {
            case .food(var item):
                item.isSelected = newValue
                self = .food(item)
            case .water(var item):
                item.isSelected = newValue
                self = .water(item)
            }
        }
    }
}

@Observable
@MainActor
final class ScanResultViewModel {
    
    var items: [EditableScanResultItem]
    
    var isLoading = false
    var error: AppError?
    var fieldErrors: [UUID: FormFieldErrors] = [:]
    var categories: [FoodCategory] = []
    var categoriesError: AppError?
    @ObservationIgnored private var uploadedImageUrl: String?
    
    private let prefsStore: PreferencesStore
    private let service: FoodServiceProtocol
    private let todayFoodVM: TodayFoodViewModel
    private let waterViewModel: WaterViewModel
    private let imageData: Data?
    @ObservationIgnored private weak var coordinator: AppCoordinator?
    @ObservationIgnored private let analyticsTracker: AnalyticsTracking?
    
    var preferredUnits: PreferredUnits { prefsStore.preferredUnits }

    func fieldError(for itemID: UUID, field: String) -> String? {
        fieldErrors[itemID]?[field]
    }

    private func clearFieldError(for itemID: UUID, field: String) {
        guard var errors = fieldErrors[itemID] else { return }
        errors.clear(field)
        fieldErrors[itemID] = errors.isEmpty ? nil : errors
    }

    func trackScreenView() {
        analyticsTracker?.track(.screenView(screen: "scan_result"))
    }
    
    var previewImage: UIImage? {
        guard let imageData else { return nil }
        return UIImage(data: imageData)
    }
    
    init(
        items: [ScanAnalysisItem],
        imageData: Data?,
        service: FoodServiceProtocol,
        todayFoodVM: TodayFoodViewModel,
        waterViewModel: WaterViewModel,
        coordinator: AppCoordinator?,
        prefsStore: PreferencesStore = PreferencesStore.shared,
        analyticsTracker: AnalyticsTracking? = nil
    ) {
        self.items = items.map { item in
            switch item {
            case .food(let food):
                .food(EditableScanFood(food, preferred: prefsStore.preferredUnits))
            case .water(let water):
                .water(EditableScanWater(water))
            }
        }
        self.imageData = imageData
        self.service = service
        self.todayFoodVM = todayFoodVM
        self.waterViewModel = waterViewModel
        self.coordinator = coordinator
        self.prefsStore = prefsStore
        self.analyticsTracker = analyticsTracker
    }
    
    var selectedItems: [EditableScanResultItem] {
        items.filter(\.isSelected)
    }

    var selectedFoodItems: [EditableScanFood] {
        selectedItems.compactMap {
            guard case .food(let item) = $0 else { return nil }
            return item
        }
    }

    var selectedWaterItems: [EditableScanWater] {
        selectedItems.compactMap {
            guard case .water(let item) = $0 else { return nil }
            return item
        }
    }
    
    var totalCalories: Double {
        selectedFoodItems.map { $0.calories(preferred: preferredUnits) }.reduce(0, +)
    }
    
    var totalGrams: Double {
        selectedFoodItems.map { $0.grams(preferred: preferredUnits) }.reduce(0, +)
    }
    
    var totalCaloriesText: String {
        UnitConversion.formatEnergy(
            kcal: totalCalories,
            preferred: preferredUnits
        )
    }
    
    var totalGramsText: String {
        UnitConversion.formatMacro(grams: totalGrams, preferred: preferredUnits)
    }

    var totalWaterMl: Int {
        selectedWaterItems.compactMap(\.amountMl).reduce(0, +)
    }
    
    func updateName(id: UUID, _ text: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        guard case .food(var item) = items[index] else { return }
        item.nameText = text
        clearFieldError(for: id, field: "name")
        items[index] = .food(item)
    }
    
    func updateCaloriesText(id: UUID, _ text: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        guard case .food(var item) = items[index] else { return }
        item.caloriesText = text
        clearFieldError(for: id, field: "calories")
        items[index] = .food(item)
    }
    
    func updateMacroText(id: UUID, field: EditableScanFood.MacroField, _ text: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        guard case .food(var item) = items[index] else { return }
        switch field {
        case .protein:
            item.proteinText = text
        case .fat:
            item.fatText = text
        case .carbs:
            item.carbsText = text
        }
        let fieldName: String
        switch field {
        case .protein: fieldName = "protein"
        case .fat: fieldName = "fat"
        case .carbs: fieldName = "carbs"
        }
        clearFieldError(for: id, field: fieldName)
        items[index] = .food(item)
    }
    
    func updateGramsText(id: UUID, _ text: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        guard case .food(var item) = items[index] else { return }
        item.gramsText = text
        clearFieldError(for: id, field: "grams")
        item.recalculateMacros(preferred: preferredUnits)
        items[index] = .food(item)
    }
    
    func toggle(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isSelected.toggle()
    }
    
    func setCategory(id: UUID, _ category: String?) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        guard case .food(var item) = items[index] else { return }
        item.categoryText = category ?? ""
        items[index] = .food(item)
    }

    func updateWaterAmount(id: UUID, _ text: String) {
        guard let index = items.firstIndex(where: { $0.id == id }), case .water(var item) = items[index] else { return }
        item.amountMlText = text
        clearFieldError(for: id, field: "amountMl")
        items[index] = .water(item)
    }
    
    func loadCategories() async {
        guard categories.isEmpty else { return }
        categoriesError = nil
        do {
            categories = try await service.getCategories()
        } catch {
            let mapped = ErrorMapper.map(error)
            if mapped == .unauthorized {
                coordinator?.goToAuth()
            }
            categoriesError = mapped == .cancelled ? nil : mapped
        }
    }
    
    func retryCategories() {
        Task { await loadCategories() }
    }
    
    private func validate(_ food: EditableScanFood) -> FormFieldErrors {
        var errors = FormFieldErrors()

        if food.nameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.set(FormErrorMapper.message(for: FieldErrorCode.required.rawValue), for: "name")
        }
        let grams = UnitConversion.parseDecimal(food.gramsText)
        if grams == nil || grams! <= 0 {
            errors.set(FormErrorMapper.message(for: FieldErrorCode.invalidValue.rawValue), for: "grams")
        }
        let calories = UnitConversion.parseDecimal(food.caloriesText)
        if calories == nil || calories! <= 0 {
            errors.set(FormErrorMapper.message(for: FieldErrorCode.invalidValue.rawValue), for: "calories")
        }
        for (field, value) in [("protein", food.proteinText), ("fat", food.fatText), ("carbs", food.carbsText)] {
            if !value.isEmpty && UnitConversion.macroGrams(fromDisplay: value, preferred: preferredUnits) == nil {
                errors.set(FormErrorMapper.message(for: FieldErrorCode.invalidValue.rawValue), for: field)
            }
        }
        return errors
    }

    func addToDiary() async -> Bool {
        guard !isLoading else { return false }
        let selected = selectedItems
        guard !selected.isEmpty else { return false }
        let foods = selectedFoodItems
        let water = selectedWaterItems

        fieldErrors.removeAll()
        for food in foods {
            let errors = validate(food)
            if !errors.isEmpty {
                fieldErrors[food.id] = errors
            }
        }
        for waterItem in water where waterItem.amountMl == nil {
            var errors = FormFieldErrors()
            errors.set(FormErrorMapper.message(for: FieldErrorCode.invalidValue.rawValue), for: "amountMl")
            fieldErrors[waterItem.id] = errors
        }
        guard fieldErrors.isEmpty else { return false }

        isLoading = true
        error = nil
        defer { isLoading = false }
        
        var imageUrl = uploadedImageUrl
        if !foods.isEmpty, imageUrl == nil, let imageData {
            do {
                imageUrl = try await service.uploadImage(imageData)
                uploadedImageUrl = imageUrl
            } catch {
                // A missing photo must not block saving the food itself.
                print("[ScanVM] photo upload failed, continuing without image")
            }
        }
        
        var failed: [String] = []
        var failedIds: [UUID] = []
        for item in foods {
            do {
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
            } catch {
                switch ErrorHandler.handle(
                    error,
                    supportedFields: ["name", "grams", "calories", "protein", "fat", "carbs"]
                ) {
                case .fieldErrors(let errors):
                    fieldErrors[item.id] = errors
                    failedIds.append(item.id)
                case .general(let appError):
                    if appError == .unauthorized {
                        coordinator?.goToAuth()
                        self.error = appError
                        return false
                    }
                    if appError != .cancelled {
                        failed.append(item.name)
                        failedIds.append(item.id)
                    }
                }
            }
        }

        for item in water {
            guard let amountMl = item.amountMl else {
                failed.append("Water")
                failedIds.append(item.id)
                continue
            }

            if !(await waterViewModel.createWater(amountMl: amountMl)) {
                failed.append("Water (\(amountMl) ml)")
                failedIds.append(item.id)
            }
        }

        if !foods.isEmpty {
            await todayFoodVM.reloadAfterMutation()
            todayFoodVM.notifyDataMutated()
        }
        
        if !fieldErrors.isEmpty && failed.isEmpty {
            for index in items.indices where !failedIds.contains(items[index].id) {
                items[index].isSelected = false
            }
            return false
        }

        if failed.isEmpty {
            return true
        }
        
        error = .partialSave(
            succeeded: selected.count - failed.count,
            total: selected.count,
            failedNames: failed
        )
        // Keep only the items that failed selected, so a retry re-sends those
        // alone instead of duplicating the ones already in the diary.
        for index in items.indices where !failedIds.contains(items[index].id) {
            items[index].isSelected = false
        }
        return false
    }
}
