import SwiftUI
import Kingfisher

struct FoodCard: View {

    let entry: FoodEntry
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    @State private var showDeleteAlert = false
    @State private var prefsStore = PreferencesStore.shared

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Button {
                onEdit?()
            } label: {
                HStack(alignment: .center, spacing: 14) {
                    imageView

                    VStack(alignment: .leading, spacing: 8) {
                        FoodCardHeader(name: entry.name)

                        FoodCardMetadata(
                            time: formatTime(entry.createdAt),
                            categoryName: entry.categoryName,
                            categoryIcon: entry.categoryIcon,
                            categoryColor: categoryColor
                        )

                        FoodCardMacros(
                            protein: entry.protein ?? 0,
                            fat: entry.fat ?? 0,
                            carbs: entry.carbs ?? 0,
                            preferredUnits: prefsStore.preferredUnits
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 10) {
                HStack(spacing: 0) {
                    FoodCardActionButton(
                        title: "Edit Food",
                        systemImage: "pencil",
                        color: AppColors.accent,
                        action: { onEdit?() }
                    )

                    FoodCardActionButton(
                        title: "Delete Food",
                        systemImage: "trash",
                        color: AppColors.error,
                        action: { showDeleteAlert = true }
                    )
                }
                .frame(width: 88, alignment: .trailing)

                FoodCardNutritionSummary(
                    energyValue: UnitConversion.formatEnergyValueText(
                        kcal: entry.calories,
                        preferred: prefsStore.preferredUnits
                    ),
                    energyUnit: UnitConversion.formatEnergyUnit(
                        preferred: prefsStore.preferredUnits
                    ),
                    portion: entry.grams.flatMap { grams in
                        grams > 0
                            ? UnitConversion.formatPortionAmount(
                                grams: grams,
                                unit: entry.unit,
                                preferred: prefsStore.preferredUnits
                            )
                            : nil
                    }
                )
                .frame(width: 44, alignment: .trailing)
            }
            .frame(width: 88, alignment: .trailing)
            .padding(.trailing, -4)
        }
        .padding(14)
        .appGlassSurface(cornerRadius: AppRadius.large)
        .alert("Delete Food", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Delete \"\(entry.name)\"?")
        }
    }

    private var categoryColor: Color {
        entry.categoryColor.flatMap(Color.init(hex:)) ?? AppColors.accent
    }

    @ViewBuilder
    private var imageView: some View {
        if let url = entry.imageUrl.flatMap(ImageURLResolver.resolve) {
            ZStack {
                fallbackIcon
                NutriflowImage(url: url)
            }
            .frame(width: 84, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        } else {
            fallbackIcon
        }
    }

    private var fallbackIcon: some View {
        FoodImagePlaceholder(cornerRadius: AppRadius.medium, iconSize: 30)
            .frame(width: 84, height: 84)
    }

    private func formatTime(_ value: String) -> String {
        AppDate.formatTime(value)
    }
}

private struct FoodCardHeader: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.headline)
            .foregroundStyle(AppColors.textPrimary)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
            .layoutPriority(1)
    }
}

private struct FoodCardActionButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(title, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .font(.subheadline.bold())
            .foregroundStyle(color)
            .frame(width: 30, height: 30)
            .background(color.opacity(0.12), in: Circle())
            .frame(width: 44, height: 44, alignment: .trailing)
    }
}

private struct FoodCardNutritionSummary: View {
    let energyValue: String
    let energyUnit: String
    let portion: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(energyValue)
                    .font(.subheadline.bold())
                    .foregroundStyle(AppColors.accent)

                Text(energyUnit)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            if let portion {
                Text(portion)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct FoodCardMetadata: View {
    let time: String
    let categoryName: String?
    let categoryIcon: String?
    let categoryColor: Color

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .foregroundStyle(AppColors.textTertiary)
                    .font(.caption)
                Text(time)
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if let categoryName, !categoryName.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: categoryIcon ?? "tag.fill")
                        .foregroundStyle(categoryColor)
                        .font(.caption)
                    Text(categoryName)
                        .font(.caption)
                        .foregroundStyle(categoryColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
        }
        .font(.caption)
        .lineLimit(1)
    }
}

private struct FoodCardMacros: View {
    let protein: Double
    let fat: Double
    let carbs: Double
    let preferredUnits: PreferredUnits

    var body: some View {
        HStack(spacing: 4) {
            MacroDot(
                color: Color(red: 0.22, green: 0.6, blue: 0.99),
                label: "P",
                value: UnitConversion.formatMacro(grams: protein, preferred: preferredUnits)
            )
            MacroDot(
                color: Color(red: 1.0, green: 0.58, blue: 0.18),
                label: "F",
                value: UnitConversion.formatMacro(grams: fat, preferred: preferredUnits)
            )
            MacroDot(
                color: Color(red: 0.28, green: 0.82, blue: 0.38),
                label: "C",
                value: UnitConversion.formatMacro(grams: carbs, preferred: preferredUnits)
            )
        }
    }
}

private struct MacroDot: View {
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)

            Text(label)
                .font(.caption.bold())
                .foregroundStyle(color)

            Text(value)
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }
}


struct MacroBadge: View {

    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(AppColors.accent)

            Text(value)
                .font(.caption)
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview("Food card with category") {
    FoodCard(
        entry: FoodEntry(
            id: "preview-food",
            userId: "preview-user",
            name: "Greek yogurt with berries",
            calories: 150,
            protein: 30.33,
            fat: 80.77,
            carbs: 90.55,
            foodId: nil,
            grams: 170,
            unit: "g",
            categoryName: "Breakfast",
            categoryIcon: "sunrise.fill",
            imageUrl: nil,
            createdAt: "2026-11-13T08:30:00Z",
            updatedAt: nil
        )
    )
    .padding()
    .background(AppColors.background)
}
