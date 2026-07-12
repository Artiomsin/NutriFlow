import SwiftUI
import Kingfisher

struct FoodSearchView: View {
    let foodService: FoodServiceProtocol
    let onSelect: (CatalogFood, Int?, String?) -> Void

    @State private var foodSearchVM: FoodSearchViewModel

    init(foodService: FoodServiceProtocol, onSelect: @escaping (CatalogFood, Int?, String?) -> Void) {
        self.foodService = foodService
        self.onSelect = onSelect
        _foodSearchVM = State(initialValue: FoodSearchViewModel(service: foodService))
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            content
        }
        .background(AppTheme.background)
        .navigationTitle("Search Food")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)

            TextField("Search food...", text: $foodSearchVM.query)
                .foregroundColor(AppTheme.textPrimary)
                .autocorrectionDisabled()
                .onChange(of: foodSearchVM.query) { _, _ in foodSearchVM.search() }

            if !foodSearchVM.query.isEmpty {
                Button {
                    foodSearchVM.query = ""
                    foodSearchVM.reset()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textTertiary)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.cardBackground)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .animation(.easeInOut(duration: 0.2), value: foodSearchVM.query.isEmpty)
    }

    @ViewBuilder
    private var content: some View {
        switch foodSearchVM.state {

        case .idle:
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "carrot.fill")
                    .font(.system(size: 40))
                    .foregroundColor(AppTheme.textTertiary)
                Text("Start typing to search")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
            }

        case .searching:
            VStack {
                Spacer()
                ProgressView()
                    .tint(AppTheme.accent)
                    .scaleEffect(1.2)
                Spacer()
            }

        case .error(let error):
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundColor(.red.opacity(0.7))
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            }

        case .results(let foods):

            if foods.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text("No results found")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 14),
                            GridItem(.flexible(), spacing: 14)
                        ],
                        spacing: 14
                    ) {
                        ForEach(foods, id: \.stableId) { food in
                            FoodCardSearch(food: food) {
                                onSelect(food, foodSearchVM.suggestedGrams, foodSearchVM.suggestedUnit)
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                    .padding(14)
                    .animation(.easeInOut(duration: 0.3), value: foods.count)
                }
                .scrollDismissesKeyboard(.immediately)
            }
        }
    }
}

struct FoodCardSearch: View {

    let food: CatalogFood
    let action: () -> Void
    @State private var prefsStore = PreferencesStore.shared

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                imageSection
                infoSection
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var imageSection: some View {
        let showImage = food.displayImageUrl.flatMap { URL(string: $0) }

        return Color.clear
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .overlay(
                Group {
                    if let imageURL = showImage {
                        ZStack {
                            fallbackImage
                            KFImage(imageURL)
                                .resizable()
                                .scaledToFill()
                        }
                    } else {
                        fallbackImage
                    }
                }
            )
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 40)
            }
            .overlay(alignment: .bottomLeading) {
                if let brand = food.brand, !brand.isEmpty, brand != "NOT A BRANDED ITEM" {
                    Text(brand)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding([.bottom, .leading], 10)
                }
            }
            .clipped()
    }

    private var fallbackImage: some View {
        ZStack {
            Color(red: 0.06, green: 0.1, blue: 0.15)
            Image(systemName: "fork.knife")
                .font(.system(size: 28))
                .foregroundColor(AppTheme.textTertiary.opacity(0.3))
        }
    }

    private var infoSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                SourceBadge(source: food.source)

                Text("\(UnitConversion.formatEnergyValue(kcal: food.caloriesPer100g, preferred: prefsStore.preferredUnits)) \(UnitConversion.formatEnergyUnit(preferred: prefsStore.preferredUnits))")
                    .font(.caption)
                    .foregroundColor(AppTheme.textTertiary)
            }

            Spacer()

            HStack(spacing: 8) {
                MacroVal(value: UnitConversion.formatMacro(grams: food.proteinPer100g ?? 0, preferred: prefsStore.preferredUnits), label: "P",
                         color: Color(red: 0.22, green: 0.6, blue: 0.99))
                MacroVal(value: UnitConversion.formatMacro(grams: food.fatPer100g ?? 0, preferred: prefsStore.preferredUnits), label: "F",
                         color: Color(red: 1.0, green: 0.58, blue: 0.18))
                MacroVal(value: UnitConversion.formatMacro(grams: food.carbsPer100g ?? 0, preferred: prefsStore.preferredUnits), label: "C",
                         color: Color(red: 0.28, green: 0.82, blue: 0.38))
            }
        }
        .padding(12)
    }
}

private struct MacroVal: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(AppTheme.textTertiary)
        }
    }
}

struct SourceBadge: View {
    let source: String

    private var label: String {
        switch source {
        case "usda_sr": return "USDA SR Legacy"
        case "usda": return "USDA Branded"
        case "openfoodfacts": return "OpenFoodFacts"
        case "user": return "My Food"
        case "local": return "System"
        default: return source
        }
    }

    private var color: Color {
        switch source {
        case "usda_sr": return Color(red: 0.2, green: 0.5, blue: 1.0)
        case "usda": return Color(red: 0.6, green: 0.3, blue: 0.9)
        case "openfoodfacts": return Color(red: 0.2, green: 0.8, blue: 0.3)
        case "user": return Color(red: 0.9, green: 0.6, blue: 0.2)
        case "local": return Color(red: 0.5, green: 0.5, blue: 0.5)
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .foregroundColor(color)
        .clipShape(Capsule())
    }
}


