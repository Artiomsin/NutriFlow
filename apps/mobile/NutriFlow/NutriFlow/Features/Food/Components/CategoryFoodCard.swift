import SwiftUI

struct CategoryFoodCard: View {
    let food: CatalogFood

    private var isPersonal: Bool {
        food.source == "user"
    }

    var body: some View {
        HStack(spacing: 12) {
            foodImage

            VStack(alignment: .leading, spacing: 6) {
                Text(food.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(isPersonal ? "Personal" : "System")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isPersonal ? AppColors.accent : AppColors.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            (isPersonal ? AppColors.accent : AppColors.surfaceSecondary)
                                .opacity(isPersonal ? 0.12 : 1),
                            in: .capsule
                        )

                    Text("\(food.caloriesPer100g.formatted(.number.precision(.fractionLength(0)))) kcal · 100 g")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.accent)
                }

                HStack(spacing: 5) {
                    nutrientBadge(
                        title: "P",
                        value: food.proteinPer100g ?? 0,
                        color: AppColors.success
                    )
                    nutrientBadge(title: "F", value: food.fatPer100g ?? 0, color: .orange)
                    nutrientBadge(title: "C", value: food.carbsPer100g ?? 0, color: .blue)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var foodImage: some View {
        if let url = food.imageUrl.flatMap(ImageURLResolver.resolve) {
            ZStack {
                FoodImagePlaceholder(cornerRadius: 12, iconSize: 23)
                NutriflowImage(url: url)
            }
            .frame(width: 56, height: 56)
            .clipShape(.rect(cornerRadius: 12))
        } else {
            FoodImagePlaceholder(cornerRadius: 12, iconSize: 23)
                .frame(width: 56, height: 56)
        }
    }

    private func nutrientBadge(title: String, value: Double, color: Color) -> some View {
        Text("\(title) \(value.formatted(.number.precision(.fractionLength(1)))) g")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: .capsule)
    }

    private var accessibilityLabel: String {
        let source = isPersonal ? "personal" : "system"
        return "\(food.name), \(source) food, \(food.caloriesPer100g.formatted(.number.precision(.fractionLength(0)))) calories per 100 grams."
    }
}
