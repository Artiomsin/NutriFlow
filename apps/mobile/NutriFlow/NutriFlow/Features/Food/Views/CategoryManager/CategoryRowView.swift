import SwiftUI

/// Single category row: icon, name, food count, and edit/delete actions (personal only).
struct CategoryRowView: View {
    let category: FoodCategory
    let isPersonal: Bool
    let onTap: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    var body: some View {
        let categoryColor: Color = Color(hex: category.color ?? "#10B981") ?? AppColors.accent

        HStack(spacing: 12) {
            CategoryIconView(
                iconName: category.icon ?? FoodCategoryIcons.defaultIcon,
                color: categoryColor
            )
            .frame(width: 44, height: 44)
            .background(categoryColor.opacity(0.12))
            .clipShape(.circle)

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                Text("\(category.foodCount) foods")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer(minLength: 12)

            if isPersonal {
                HStack(spacing: 8) {
                    if let onEdit {
                        Button {
                            onEdit()
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppColors.accent)
                                .padding(8)
                                .background(AppColors.accent.opacity(0.1), in: .circle)
                        }
                        .buttonStyle(.plain)
                    }

                    if let onDelete {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppColors.error)
                                .padding(8)
                                .background(AppColors.error.opacity(0.1), in: .circle)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("System")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColors.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.surfaceSecondary)
                    .clipShape(.capsule)
            }
        }
        .padding(12)
        .background(AppColors.surface, in: .rect(cornerRadius: AppRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.large)
                .stroke(AppColors.border.opacity(0.5), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}
