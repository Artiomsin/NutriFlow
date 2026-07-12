import SwiftUI
import Kingfisher

struct ServingPickerView: View {
    let food: CatalogFood
    let foodService: FoodServiceProtocol
    let todayFoodVM: TodayFoodViewModel
    let suggestedGrams: Int?
    let suggestedUnit: String?
    let onSave: () -> Void

    @State private var gramsText: String = ""
    @State private var selectedServing: FoodServing?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var gramFieldFocused: Bool

    init(food: CatalogFood, foodService: FoodServiceProtocol, todayFoodVM: TodayFoodViewModel, suggestedGrams: Int? = nil, suggestedUnit: String? = nil, onSave: @escaping () -> Void) {
        self.food = food
        self.foodService = foodService
        self.todayFoodVM = todayFoodVM
        self.suggestedGrams = suggestedGrams
        self.suggestedUnit = suggestedUnit
        self.onSave = onSave
        if let sg = suggestedGrams, sg > 0 {
            _gramsText = State(initialValue: gramsToDisplay(sg))
        }
    }

    @State private var prefsStore = PreferencesStore.shared

    private var displayUnit: String {
        if suggestedUnit == "ml" || suggestedUnit == "l" {
            return prefsStore.preferredUnits.volume == .imperial ? "fl oz" : "ml"
        }
        return prefsStore.preferredUnits.weight == .imperial ? "oz" : "g"
    }

    private var grams: Int {
        let normalized = gramsText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else {
            if let serving = selectedServing { return serving.grams }
            return 100
        }
        switch displayUnit {
        case "fl oz": return Int((value * 29.5735).rounded())
        case "oz": return Int((value * 28.35).rounded())
        default: return Int(value.rounded())
        }
    }

    private var ratio: Double { Double(grams) / 100.0 }

    private func gramsToDisplay(_ g: Int) -> String {
        switch displayUnit {
        case "fl oz": return String(format: "%.1f", Double(g) / 29.5735)
        case "oz": return String(format: "%.1f", Double(g) / 28.35)
        default: return "\(g)"
        }
    }

    private var calculatedCalories: Int { Int(Double(food.caloriesPer100g) * ratio) }
    private var calculatedProtein: Int { food.proteinPer100g.map { Int(Double($0) * ratio) } ?? 0 }
    private var calculatedFat: Int { food.fatPer100g.map { Int(Double($0) * ratio) } ?? 0 }
    private var calculatedCarbs: Int { food.carbsPer100g.map { Int(Double($0) * ratio) } ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                macroComparison
                if (food.servings?.isEmpty == false) { servingGrid }
                gramInput
                saveButton
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                gramFieldFocused = false
            }
        }
        .background(AppTheme.background)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    gramFieldFocused = false
                }
                .fontWeight(.semibold)
            }
        }
        .navigationTitle("Add Portion")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.cardBackground)
                    .frame(width: 72, height: 72)

                if let url = food.displayImageUrl, let imageURL = URL(string: url) {
                    ZStack {
                        Image(systemName: "fork.knife")
                            .font(.title2)
                            .foregroundColor(AppTheme.textTertiary)
                        KFImage(imageURL)
                            .resizable()
                            .scaledToFill()
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    Image(systemName: "fork.knife")
                        .font(.title2)
                        .foregroundColor(AppTheme.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(2)

                if let brand = food.brand, !brand.isEmpty, brand != "NOT A BRANDED ITEM" {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }

                SourceBadge(source: food.source)
            }

            Spacer()
        }
    }

    private var macroComparison: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Per 100g")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Text("For \(UnitConversion.formatAmount(grams: grams, unit: suggestedUnit ?? "g", preferred: PreferencesStore.shared.preferredUnits))")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppTheme.accent)
            }

            HStack(spacing: 8) {
                MacroCard(
                    label: "Calories",
                    per100: "\(food.caloriesPer100g)",
                    total: "\(UnitConversion.formatEnergyValue(kcal: calculatedCalories, preferred: PreferencesStore.shared.preferredUnits))",
                    color: .orange,
                    unit: UnitConversion.formatEnergyUnit(preferred: PreferencesStore.shared.preferredUnits)
                )
                MacroCard(
                    label: "Protein",
                    per100: UnitConversion.formatMacro(grams: food.proteinPer100g ?? 0, preferred: PreferencesStore.shared.preferredUnits),
                    total: UnitConversion.formatMacro(grams: calculatedProtein, preferred: PreferencesStore.shared.preferredUnits),
                    color: Color(red: 0.9, green: 0.3, blue: 0.3),
                    unit: ""
                )
                MacroCard(
                    label: "Fat",
                    per100: UnitConversion.formatMacro(grams: food.fatPer100g ?? 0, preferred: PreferencesStore.shared.preferredUnits),
                    total: UnitConversion.formatMacro(grams: calculatedFat, preferred: PreferencesStore.shared.preferredUnits),
                    color: Color(red: 0.2, green: 0.5, blue: 0.9),
                    unit: ""
                )
                MacroCard(
                    label: "Carbs",
                    per100: UnitConversion.formatMacro(grams: food.carbsPer100g ?? 0, preferred: PreferencesStore.shared.preferredUnits),
                    total: UnitConversion.formatMacro(grams: calculatedCarbs, preferred: PreferencesStore.shared.preferredUnits),
                    color: Color(red: 0.2, green: 0.7, blue: 0.3),
                    unit: ""
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.cardBackground)
        )
    }

    private var servingGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preset servings")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(food.servings ?? []) { serving in
                    Button {
                        selectedServing = serving
                        gramsText = gramsToDisplay(serving.grams)
                    } label: {
                        VStack(spacing: 2) {
                            Text(serving.name)
                                .font(.caption.weight(.medium))
                                .foregroundColor(selectedServing?.id == serving.id ? .white : AppTheme.textPrimary)
                                .lineLimit(1)
                            Text(UnitConversion.formatAmount(grams: serving.grams, unit: "g", preferred: PreferencesStore.shared.preferredUnits))
                                .font(.caption2)
                                .foregroundColor(selectedServing?.id == serving.id ? .white.opacity(0.8) : AppTheme.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedServing?.id == serving.id ? AppTheme.accent : AppTheme.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedServing?.id == serving.id ? Color.clear : Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var gramInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Custom amount")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                if let sg = suggestedGrams {
                    Button(UnitConversion.formatAmount(grams: sg, unit: suggestedUnit ?? "g", preferred: PreferencesStore.shared.preferredUnits)) {
                        gramsText = gramsToDisplay(sg)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(AppTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.accent.opacity(0.12), in: Capsule())
                }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(suggestedUnit == "ml"
                         ? (PreferencesStore.shared.preferredUnits.volume == .imperial ? "Fluid Ounces" : "Milliliters")
                         : (PreferencesStore.shared.preferredUnits.weight == .imperial ? "Ounces" : "Grams"))
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)

                    TextField("", text: $gramsText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.decimalPad)
                        .focused($gramFieldFocused)
                        .foregroundColor(AppTheme.textPrimary)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                                .fill(AppTheme.fieldBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                                        .stroke(AppTheme.fieldBorder, lineWidth: 1)
                                )
                        )
                }
                Text(displayUnit)
                    .font(.title3.weight(.medium))
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
    }

    private var saveButton: some View {
        Button {
            Task {
                isLoading = true
                errorMessage = nil

                let cal = calculatedCalories
                let prot = food.proteinPer100g.map { Int(Double($0) * ratio) }
                let ft = food.fatPer100g.map { Int(Double($0) * ratio) }
                let crb = food.carbsPer100g.map { Int(Double($0) * ratio) }

                do {
                    try await foodService.createFoodEntry(
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
                    onSave()
                } catch {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.black)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.subheadline)
                    Text("Add to Diary — \(UnitConversion.formatEnergy(kcal: calculatedCalories, preferred: PreferencesStore.shared.preferredUnits))")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [AppTheme.accent, AppTheme.accent.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .foregroundColor(.black)
            .shadow(color: AppTheme.accent.opacity(0.3), radius: 12, y: 6)
        }
        .disabled(isLoading || grams <= 0)
        .opacity((isLoading || grams <= 0) ? 0.6 : 1)
        .animation(.easeInOut(duration: 0.2), value: grams)
    }
}

private struct MacroCard: View {
    let label: String
    let per100: String
    let total: String
    let color: Color
    let unit: String

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppTheme.textTertiary)

            Text(total)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
                .contentTransition(.numericText())
                .animation(.snappy, value: total)

            HStack(spacing: 2) {
                Text(per100)
                    .font(.system(size: 9, weight: .medium))
                Text(unit)
                    .font(.system(size: 8))
            }
            .foregroundColor(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.12), lineWidth: 0.5)
        )
    }
}

#Preview {
    NavigationStack {
        ServingPickerView(
            food: CatalogFood(
                id: "1",
                name: "Chicken Breast",
                categoryId: nil,
                categoryName: nil,
                brand: "Organic Farms",
                caloriesPer100g: 165,
                proteinPer100g: 31,
                fatPer100g: 4,
                carbsPer100g: 0,
                barcode: nil,
                imageUrl: nil,
                source: "openfoodfacts",
                createdBy: nil,
                createdAt: "",
                updatedAt: "",
                servings: [
                    FoodServing(id: "1", foodId: "1", name: "100g", grams: 100, createdAt: nil),
                    FoodServing(id: "2", foodId: "1", name: "1 breast", grams: 200, createdAt: nil)
                ]
            ),
            foodService: MockFoodService(),
            todayFoodVM: TodayFoodViewModel(service: MockFoodService(), coordinator: nil),
            suggestedGrams: 200,
            onSave: {}
        )
    }
    .preferredColorScheme(.dark)
}
