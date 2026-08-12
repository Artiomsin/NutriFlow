import SwiftUI

struct FoodSection: View {

    @Bindable var todayFoodVM: TodayFoodViewModel
    var onAddFood: (() -> Void)?
    var onEditFood: ((FoodEntry) -> Void)?
    var onDeleteFood: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            content
        }
    }

    private var header: some View {
        HStack {
            Text("Today's Food")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Button {
                onAddFood?()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("Add")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(AppTheme.accent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch todayFoodVM.state {

        case .idle, .loading:
            ProgressView()
                .tint(AppTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)

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
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
        }
    }

    private func sortedEntries(_ entries: [FoodEntry]) -> [FoodEntry] {
        entries.sorted { $0.createdAt > $1.createdAt }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "fork.knife")
                .font(.system(size: 32))
                .foregroundColor(AppTheme.textTertiary)

            Text("No meals logged today")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    FoodSectionPreview()
}

struct FoodSectionPreview: View {
    var body: some View {
        let todayFoodVM = TodayFoodViewModel(
            service: MockFoodService(),
            coordinator: AppCoordinator(container: AppDependencyContainer())
        )
        todayFoodVM.setPreviewState(.loaded([
            FoodEntry(id: "1", userId: "1", name: "Chicken breast", calories: 165, protein: 31, fat: 4, carbs: 0, foodId: nil, grams: 200, unit: "g", categoryName: "Meat", imageUrl: nil, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil),
            FoodEntry(id: "2", userId: "1", name: "Brown rice", calories: 200, protein: 4, fat: 1, carbs: 45, foodId: nil, grams: 150, unit: "g", categoryName: "Grains", imageUrl: nil, createdAt: "2026-05-18T12:00:00Z", updatedAt: nil),
            FoodEntry(id: "3", userId: "1", name: "Greek salad", calories: 185, protein: 6, fat: 12, carbs: 8, foodId: nil, grams: 250, unit: "g", categoryName: "Salad", imageUrl: nil, createdAt: "2026-05-18T14:00:00Z", updatedAt: nil)
        ]))

        return FoodSection(
            todayFoodVM: todayFoodVM,
            onAddFood: {},
            onDeleteFood: { _ in }
        )
        .padding()
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
    }
}
