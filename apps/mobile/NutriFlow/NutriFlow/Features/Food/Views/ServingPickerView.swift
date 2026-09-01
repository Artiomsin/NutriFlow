import SwiftUI
import Kingfisher

struct ServingPickerView: View {
    @State private var viewModel: ServingPickerViewModel
    let onSave: () -> Void

    @FocusState private var gramFieldFocused: Bool
    @State private var prefsStore = PreferencesStore.shared

    init(viewModel: ServingPickerViewModel, onSave: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSave = onSave
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                macroComparison
                if (viewModel.food.servings?.isEmpty == false) { servingGrid }
                gramInput
                saveButton
                if let error = viewModel.errorMessage {
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
        .navigationTitle("Add Portion")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.cardBackground)
                    .frame(width: 72, height: 72)

                if let url = viewModel.food.displayImageUrl, let imageURL = URL(string: url) {
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
                Text(viewModel.food.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(2)

                if let brand = viewModel.food.brand, !brand.isEmpty, brand != "NOT A BRANDED ITEM" {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }

                SourceBadge(source: viewModel.food.source)
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
                Text("For \(UnitConversion.formatAmount(grams: viewModel.grams, unit: viewModel.suggestedUnit ?? "g", preferred: prefsStore.preferredUnits))")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppTheme.accent)
            }

            HStack(spacing: 8) {
                MacroCard(
                    label: "Calories",
                    per100: "\(viewModel.food.caloriesPer100g)",
                    total: "\(UnitConversion.formatEnergyValue(kcal: viewModel.calculatedCalories, preferred: prefsStore.preferredUnits))",
                    color: .orange,
                    unit: UnitConversion.formatEnergyUnit(preferred: prefsStore.preferredUnits)
                )
                MacroCard(
                    label: "Protein",
                    per100: UnitConversion.formatMacro(grams: viewModel.food.proteinPer100g ?? 0, preferred: prefsStore.preferredUnits),
                    total: UnitConversion.formatMacro(grams: viewModel.calculatedProtein, preferred: prefsStore.preferredUnits),
                    color: Color(red: 0.9, green: 0.3, blue: 0.3),
                    unit: ""
                )
                MacroCard(
                    label: "Fat",
                    per100: UnitConversion.formatMacro(grams: viewModel.food.fatPer100g ?? 0, preferred: prefsStore.preferredUnits),
                    total: UnitConversion.formatMacro(grams: viewModel.calculatedFat, preferred: prefsStore.preferredUnits),
                    color: Color(red: 0.2, green: 0.5, blue: 0.9),
                    unit: ""
                )
                MacroCard(
                    label: "Carbs",
                    per100: UnitConversion.formatMacro(grams: viewModel.food.carbsPer100g ?? 0, preferred: prefsStore.preferredUnits),
                    total: UnitConversion.formatMacro(grams: viewModel.calculatedCarbs, preferred: prefsStore.preferredUnits),
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
                ForEach(viewModel.food.servings ?? []) { serving in
                    Button {
                        viewModel.selectPreset(serving)
                    } label: {
                        VStack(spacing: 2) {
                            Text(serving.name)
                                .font(.caption.weight(.medium))
                                .foregroundColor(viewModel.selectedServing?.id == serving.id ? .white : AppTheme.textPrimary)
                                .lineLimit(1)
                            Text("\(viewModel.gramsToDisplay(serving.grams)) \(viewModel.displayUnit)")
                                .font(.caption2)
                                .foregroundColor(viewModel.selectedServing?.id == serving.id ? .white.opacity(0.8) : AppTheme.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(viewModel.selectedServing?.id == serving.id ? AppTheme.accent : AppTheme.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(viewModel.selectedServing?.id == serving.id ? Color.clear : Color.white.opacity(0.06), lineWidth: 0.5)
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

                if let sg = viewModel.suggestedGrams {
                    Button("\(viewModel.gramsToDisplay(sg)) \(viewModel.displayUnit)") {
                        viewModel.selectSuggested(sg)
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
                    Text(viewModel.suggestedUnit == "ml"
                         ? (prefsStore.preferredUnits.volume == .imperial ? "Fluid Ounces" : "Milliliters")
                         : (prefsStore.preferredUnits.weight == .imperial ? "Ounces" : "Grams"))
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)

                    TextField("", text: $viewModel.gramsText)
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
                Text(viewModel.displayUnit)
                    .font(.title3.weight(.medium))
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
    }

    private var saveButton: some View {
        Button {
            Task {
                guard await viewModel.save() else { return }
                onSave()
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.black)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.subheadline)
                    Text("Add to Diary — \(UnitConversion.formatEnergy(kcal: viewModel.calculatedCalories, preferred: prefsStore.preferredUnits))")
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
        .disabled(viewModel.isLoading || viewModel.grams <= 0)
        .opacity((viewModel.isLoading || viewModel.grams <= 0) ? 0.6 : 1)
        .animation(.easeInOut(duration: 0.2), value: viewModel.grams)
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
            viewModel: ServingPickerViewModel(
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
                service: MockFoodService(),
                todayFoodVM: TodayFoodViewModel(service: MockFoodService(), coordinator: nil),
                suggestedGrams: 200,
                suggestedUnit: nil,
                coordinator: nil
            ),
            onSave: {}
        )
    }
    .preferredColorScheme(.dark)
}
