import SwiftUI
import Kingfisher

struct FoodSearchView: View {
    let onSelect: (CatalogFood, Int?, String?) -> Void
    
    @State private var foodSearchVM: FoodSearchViewModel
    @FocusState private var searchFocused: Bool
    
    init(viewModel: FoodSearchViewModel, onSelect: @escaping (CatalogFood, Int?, String?) -> Void) {
        self.onSelect = onSelect
        _foodSearchVM = State(initialValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchBar
            content
                .contentShape(Rectangle())
                .onTapGesture { searchFocused = false }
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
                .focused($searchFocused)
                .foregroundColor(AppTheme.textPrimary)
                .autocorrectionDisabled()
                .onChange(of: foodSearchVM.query) { _, _ in foodSearchVM.search() }
                .onSubmit { searchFocused = false }
            
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
            skeletonGrid
            
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
                                foodSearchVM.selectIfLocal(food)
                                onSelect(food, foodSearchVM.suggestedGrams, foodSearchVM.suggestedUnit)
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                    .padding(14)
                    .animation(.easeInOut(duration: 0.3), value: foods.count)

                    if foodSearchVM.loadMoreError {
                        Button {
                            foodSearchVM.loadMore()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                Text("Failed to load. Retry")
                            }
                            .font(.subheadline)
                            .foregroundColor(AppTheme.accent)
                            .padding(.vertical, 16)
                        }
                    } else if foodSearchVM.hasMore || foodSearchVM.isLoadMore {
                        ProgressView()
                            .tint(AppTheme.accent)
                            .padding(.vertical, 20)
                    }
                }
                .scrollDismissesKeyboard(.immediately)
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentSize.height - geometry.containerSize.height - geometry.contentOffset.y
                } action: { _, remaining in
                    if remaining < 200 {
                        foodSearchVM.loadMore()
                    }
                }
            }
        }
    }
}

private var skeletonGrid: some View {
    ScrollView {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ],
            spacing: 14
        ) {
            ForEach(0..<10, id: \.self) { _ in
                skeletonCard
            }
        }
        .padding(14)
    }
    .scrollDisabled(true)
    .redacted(reason: .placeholder)
}

private var skeletonCard: some View {
    VStack(alignment: .leading, spacing: 0) {
        RoundedRectangle(cornerRadius: 0)
            .fill(Color.gray.opacity(0.2))
            .frame(height: 120)
            .frame(maxWidth: .infinity)
        VStack(alignment: .leading, spacing: 8) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 40, height: 8)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 80, height: 10)
        }
        .padding(12)
    }
    .background(AppTheme.cardBackground)
    .clipShape(RoundedRectangle(cornerRadius: 14))
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
        VStack(alignment: .leading, spacing: 8) {
            Text(food.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 32, alignment: .topLeading)

            HStack(spacing: 6) {
                SourceBadge(source: food.source)

                if let cat = food.categoryName, !cat.isEmpty {
                    Text(cat)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AppTheme.accent)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            AppTheme.accent.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text("\(UnitConversion.formatEnergyValue(kcal: food.caloriesPer100g, preferred: prefsStore.preferredUnits)) \(UnitConversion.formatEnergyUnit(preferred: prefsStore.preferredUnits))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textTertiary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                HStack(spacing: 7) {
                    MacroVal(value: UnitConversion.formatMacro(grams: food.proteinPer100g ?? 0, preferred: prefsStore.preferredUnits), label: "P",
                             color: Color(red: 0.22, green: 0.6, blue: 0.99))
                    MacroVal(value: UnitConversion.formatMacro(grams: food.fatPer100g ?? 0, preferred: prefsStore.preferredUnits), label: "F",
                             color: Color(red: 1.0, green: 0.58, blue: 0.18))
                    MacroVal(value: UnitConversion.formatMacro(grams: food.carbsPer100g ?? 0, preferred: prefsStore.preferredUnits), label: "C",
                             color: Color(red: 0.28, green: 0.82, blue: 0.38))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
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
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(AppTheme.textTertiary)
        }
        .frame(width: 28)
    }
}

struct SourceBadge: View {
    let source: String
    
    private var label: String {
        switch source {
        case "usda_sr": return "USDA SR"
        case "usda": return "USDA"
        case "openfoodfacts": return "OFF"
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

#Preview {
    NavigationStack {
        FoodSearchView(
            viewModel: FoodSearchViewModel(service: MockFoodService()),
            onSelect: { _, _, _ in }
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Food Card (long name)") {
    LazyVGrid(
        columns: [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ],
        spacing: 14
    ) {
        FoodCardSearch(
            food: CatalogFood(
                id: "1",
                name: "Chicken Breast, Roasted with Herbs and Spices",
                categoryId: nil,
                categoryName: "Meat, Poultry",
                brand: "Organic Farms",
                caloriesPer100g: 165,
                proteinPer100g: 31,
                fatPer100g: 4,
                carbsPer100g: 0,
                barcode: nil,
                imageUrl: nil,
                source: "user",
                createdBy: nil,
                createdAt: "",
                updatedAt: "",
                servings: nil
            ),
            action: {}
        )
        FoodCardSearch(
            food: CatalogFood(
                id: "2",
                name: "Apple",
                categoryId: nil,
                categoryName: nil,
                brand: nil,
                caloriesPer100g: 52,
                proteinPer100g: 1,
                fatPer100g: 0,
                carbsPer100g: 14,
                barcode: nil,
                imageUrl: nil,
                source: "usda",
                createdBy: nil,
                createdAt: "",
                updatedAt: "",
                servings: nil
            ),
            action: {}
        )
    }
    .padding(14)
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}


