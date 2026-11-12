import SwiftUI

/// Intro card shown at the top of Category Manager.
struct IntroductionCard: View {
    var body: some View {
        AppCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "tag.fill")
                    .font(.title3)
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 40, height: 40)
                    .background(AppColors.accent.opacity(0.12))
                    .clipShape(.circle)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Organize your foods")
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(
                        "Assign a category while adding a food. System categories are shared; yours stay private."
                    )
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }
}

/// "Manage Personal Dishes" card.
struct ManagePersonalDishesCard: View {
    let onTap: () -> Void

    var body: some View {
        AppCard {
            Button("Manage Personal Dishes", systemImage: "square.and.pencil") {
                onTap()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(AppColors.accent)
            .accessibilityHint("Select personal dishes and assign or remove categories.")
        }
    }
}

/// Skeleton loading card shown while categories load.
struct LoadingCard: View {
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                AppCard {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(AppColors.surfaceSecondary)
                            .frame(width: 40, height: 40)

                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppColors.surfaceSecondary)
                                .frame(width: 126, height: 16)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppColors.surfaceSecondary)
                                .frame(width: 64, height: 12)
                        }

                        Spacer()

                        Capsule()
                            .fill(AppColors.surfaceSecondary)
                            .frame(width: 28, height: 20)

                        Circle()
                            .fill(AppColors.surfaceSecondary)
                            .frame(width: 28, height: 28)
                    }
                    .accessibilityHidden(true)
                }
            }
        }
    }
}

/// Global empty state when search is active but nothing matches.
struct CategoryEmptySearchState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(AppColors.textTertiary)

            Text("No matching categories")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            Text("Try a different search term.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(AppColors.surface, in: .rect(cornerRadius: AppRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.large)
                .stroke(AppColors.border.opacity(0.5), lineWidth: 1)
        }
        .padding(.top, 8)
    }
}
