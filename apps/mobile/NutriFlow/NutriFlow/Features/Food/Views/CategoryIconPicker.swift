import SwiftUI

struct CategoryIconPicker: View {
    struct IconOption: Identifiable {
        let symbol: String
        let title: String

        var id: String { symbol }
    }

    static let options = [
        IconOption(symbol: "tag.fill", title: "Tag"),
        IconOption(symbol: "fork.knife", title: "Meal"),
        IconOption(symbol: "sunrise.fill", title: "Breakfast"),
        IconOption(symbol: "sun.max.fill", title: "Snack"),
        IconOption(symbol: "moon.stars.fill", title: "Dinner"),
        IconOption(symbol: "house.fill", title: "Home"),
        IconOption(symbol: "leaf.fill", title: "Vegetables"),
        IconOption(symbol: "carrot.fill", title: "Carrots"),
        IconOption(symbol: "apple.logo", title: "Fruit"),
        IconOption(symbol: "fish.fill", title: "Fish"),
        IconOption(symbol: "drumstick.fill", title: "Meat"),
        IconOption(symbol: "takeoutbag.and.cup.and.straw.fill", title: "Takeout"),
        IconOption(symbol: "cup.and.saucer.fill", title: "Drinks"),
        IconOption(symbol: "mug.fill", title: "Coffee"),
        IconOption(symbol: "wineglass.fill", title: "Beverages"),
        IconOption(symbol: "birthday.cake.fill", title: "Dessert"),
        IconOption(symbol: "frying.pan.fill", title: "Fast food"),
        IconOption(symbol: "flame.fill", title: "Favorites"),
        IconOption(symbol: "basket.fill", title: "Groceries"),
        IconOption(symbol: "pills.fill", title: "Supplements")
    ]

    @Binding var selection: String

    private let columns = [GridItem(.adaptive(minimum: 48), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Self.options) { option in
                Button {
                    selection = option.symbol
                } label: {
                    Image(systemName: option.symbol)
                        .font(.title3)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(selection == option.symbol ? AppColors.accentOnPrimary : AppColors.accent)
                        .background {
                            RoundedRectangle(cornerRadius: AppRadius.small)
                                .fill(selection == option.symbol ? AppColors.accent : AppColors.surfaceSecondary)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(selection == option.symbol ? .isSelected : [])
            }
        }
    }
}
