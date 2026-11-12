import SwiftUI

/// Delete confirmation modal shown as an overlay.
struct DeleteCategoryModal: View {
    let category: FoodCategory
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }

            VStack(spacing: 18) {
                Image(systemName: "trash")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(AppColors.error)

                VStack(spacing: 8) {
                    Text("Delete category?")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Delete \"\(category.name)\"? Your foods will remain without a category.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 14) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.headline)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.surfaceSecondary, in: .rect(cornerRadius: AppRadius.large))

                    Button("Delete") {
                        onDelete()
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.error, in: .rect(cornerRadius: AppRadius.large))
                }
            }
            .padding(24)
            .frame(maxWidth: 320)
            .background(AppColors.surface, in: .rect(cornerRadius: AppRadius.large))
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
        }
    }
}
