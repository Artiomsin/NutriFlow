import SwiftUI

struct FoodSection: View {

    @Bindable var todayFoodVM: TodayFoodViewModel
    var onAddFood: (() -> Void)?
    var onScan: (() -> Void)?
    var onEditFood: ((FoodEntry) -> Void)?
    var onDeleteFood: ((String) -> Void)?
    var onManageCategories: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let bannerError = todayFoodVM.bannerError {
                ErrorView(error: bannerError) { todayFoodVM.retryBanner() }
            }
            content
        }
    }

    private var header: some View {
        HStack {
            Text("Today's Food")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Button {
                onManageCategories?()
            } label: {
                Image(systemName: "tag.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Manage Categories")

            Button {
                onScan?()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 12, weight: .bold))
                    Text("Scan")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(AppColors.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .overlay(
                    Capsule()
                        .stroke(AppColors.accent, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)

            Button {
                onAddFood?()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("Add")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(AppColors.accentOnPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(AppColors.accent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch todayFoodVM.state {

        case .idle, .loading:
            foodSkeleton

        case .loaded(let entries):
            if entries.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(sortedEntries(entries)) { entry in
                        FoodCard(entry: entry, onEdit: { onEditFood?(entry) }, onDelete: {
                            onDeleteFood?(entry.id)
                        })
                    }
                }
            }

        case .error(let error):
            ErrorView(error: error, onRetry: { todayFoodVM.retry() })
                .padding(.vertical, 16)
        }
    }

    private func sortedEntries(_ entries: [FoodEntry]) -> [FoodEntry] {
        entries.sorted { $0.createdAt > $1.createdAt }
    }

    private var foodSkeleton: some View {
        LazyVStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { _ in
                foodSkeletonCard
            }
        }
        .accessibilityLabel("Loading food entries")
    }

    private var foodSkeletonCard: some View {
        HStack(spacing: 14) {
            skeletonPlaceholder(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    skeletonPlaceholder(width: 105, height: 15)

                    Spacer(minLength: 4)

                    skeletonPlaceholder(width: 48, height: 22)
                        .clipShape(Capsule())
                }

                skeletonPlaceholder(width: 42, height: 12)

                HStack(spacing: 5) {
                    skeletonPlaceholder(width: 10, height: 10)
                        .clipShape(Circle())

                    skeletonPlaceholder(width: 58, height: 12)
                }

                HStack(spacing: 12) {
                    macroSkeleton(width: 34)
                    macroSkeleton(width: 34)
                    macroSkeleton(width: 34)
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 6) {
                skeletonPlaceholder(width: 27, height: 27)
                    .clipShape(Circle())

                skeletonPlaceholder(width: 27, height: 27)
                    .clipShape(Circle())

                skeletonPlaceholder(width: 38, height: 12)
            }
        }
        .padding(12)
        .appGlassSurface(cornerRadius: 14)
        .accessibilityHidden(true)
    }

    private func macroSkeleton(width: CGFloat) -> some View {
        skeletonPlaceholder(width: width, height: 12)
    }

    private func skeletonPlaceholder(
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(AppColors.textSecondary.opacity(0.12))
            .frame(width: width, height: height)
    }
    
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "fork.knife")
                .font(.system(size: 32))
                .foregroundColor(AppColors.textTertiary)

            Text("No meals logged today")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .appGlassSurface(cornerRadius: 14)
    }
}

#Preview("Food - Loaded") {
    FoodSectionPreview { vm in
        vm.setPreviewState(.loaded([
            FoodEntry(
                id: "1",
                userId: "1",
                name: "Chicken breast",
                calories: 165,
                protein: 31,
                fat: 4,
                carbs: 0,
                foodId: nil,
                grams: 200,
                unit: "g",
                categoryName: "Meat",
                categoryIcon: "fork.knife",
                imageUrl: nil,
                createdAt: "2026-05-18T10:00:00Z",
                updatedAt: nil
            ),
            FoodEntry(
                id: "2",
                userId: "1",
                name: "Brown rice",
                calories: 200,
                protein: 4,
                fat: 1,
                carbs: 45,
                foodId: nil,
                grams: 150,
                unit: "g",
                categoryName: "Grains",
                categoryIcon: "fork.knife",
                imageUrl: nil,
                createdAt: "2026-05-18T12:00:00Z",
                updatedAt: nil
            ),
            FoodEntry(
                id: "3",
                userId: "1",
                name: "Greek salad",
                calories: 185,
                protein: 6,
                fat: 12,
                carbs: 8,
                foodId: nil,
                grams: 250,
                unit: "g",
                categoryName: "Salad",
                categoryIcon: "fork.knife",
                imageUrl: nil,
                createdAt: "2026-05-18T14:00:00Z",
                updatedAt: nil
            )
        ]))
    }
}

#Preview("Food - Loading") {
    FoodSectionPreview { vm in
        vm.setPreviewState(.loading)
    }
}

#Preview("Food - Empty") {
    FoodSectionPreview { vm in
        vm.setPreviewState(.loaded([]))
    }
}

struct FoodSectionPreview: View {
    let configure: (TodayFoodViewModel) -> Void

    var body: some View {
        let todayFoodVM = TodayFoodViewModel(
            service: MockFoodService(),
            coordinator: AppCoordinator(
                container: AppDependencyContainer()
            )
        )

        configure(todayFoodVM)

        return FoodSection(
            todayFoodVM: todayFoodVM,
            onAddFood: {},
            onScan: {},
            onDeleteFood: { _ in },
            onManageCategories: {}
        )
        .padding()
        .background(AppColors.background)
    }
}
