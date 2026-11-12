import SwiftUI

/// A category section: header with optional count badge / trailing button, subtitle, and rows.
struct CategorySectionView: View {
    let title: String
    let subtitle: String
    let categories: [FoodCategory]
    let isPersonal: Bool
    let countBadge: Int?
    let trailingContent: AnyView?
    let onSelect: (FoodCategory) -> Void
    let onEdit: (FoodCategory) -> Void
    let onDelete: (FoodCategory) -> Void

    init(
        title: String,
        subtitle: String,
        categories: [FoodCategory],
        isPersonal: Bool,
        countBadge: Int? = nil,
        @ViewBuilder trailingContent: () -> some View = { EmptyView() },
        onSelect: @escaping (FoodCategory) -> Void,
        onEdit: @escaping (FoodCategory) -> Void = { _ in },
        onDelete: @escaping (FoodCategory) -> Void = { _ in }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.categories = categories
        self.isPersonal = isPersonal
        self.countBadge = countBadge
        self.trailingContent = AnyView(trailingContent())
        self.onSelect = onSelect
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)

                if let countBadge {
                    Text("(\(countBadge))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.textTertiary)
                } else if let trailingContent {
                    trailingContent
                }
            }

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)

            VStack(spacing: 10) {
                ForEach(categories) { category in
                    CategoryRowView(
                        category: category,
                        isPersonal: isPersonal,
                        onTap: { onSelect(category) },
                        onEdit: { onEdit(category) },
                        onDelete: { onDelete(category) }
                    )
                }
            }
        }
    }
}
