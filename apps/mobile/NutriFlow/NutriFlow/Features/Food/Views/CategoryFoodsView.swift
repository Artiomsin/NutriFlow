import SwiftUI

struct CategoryFoodsView: View {
    let category: FoodCategory
    let availableCategories: [FoodCategory]
    let onCategoriesChanged: () async -> Void

    @State private var viewModel: CategoryFoodsViewModel
    @State private var selectedFoodIDs = Set<String>()
    @State private var isSelecting = false
    @State private var isChoosingDestination = false

    init(
        category: FoodCategory,
        availableCategories: [FoodCategory],
        viewModel: CategoryFoodsViewModel,
        onCategoriesChanged: @escaping () async -> Void
    ) {
        self.category = category
        self.availableCategories = availableCategories
        self.onCategoriesChanged = onCategoriesChanged
        _viewModel = State(initialValue: viewModel)
    }

    private var selectedCount: Int {
        selectedFoodIDs.count
    }

    private var destinationCategories: [FoodCategory] {
        availableCategories.filter { $0.id != category.id }
    }

    var body: some View {
        List {
            Section {
                Label("\(category.foodCount) foods in this category", systemImage: "tag.fill")
                    .foregroundStyle(AppColors.textSecondary)
            }

            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)

            case .error(let error):
                ErrorView(error: error) {
                    Task { await viewModel.load() }
                }

            case .loaded:
                if viewModel.foods.isEmpty {
                    ContentUnavailableView(
                        "No foods",
                        systemImage: "tray",
                        description: Text("Foods assigned to this category will appear here.")
                    )
                } else {
                    ForEach(viewModel.foods, id: \.stableId) { food in
                        foodRow(food)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isSelecting {
                    Button("Cancel") {
                        selectedFoodIDs.removeAll()
                        isSelecting = false
                    }
                } else {
                    Button("Select") {
                        isSelecting = true
                    }
                }
            }

            if isSelecting, selectedCount > 0 {
                ToolbarItem(placement: .bottomBar) {
                    Button("Change Category") {
                        isChoosingDestination = true
                    }
                    .disabled(viewModel.isUpdating)
                }
            }
        }
        .confirmationDialog(
            "Move \(selectedCount) foods",
            isPresented: $isChoosingDestination,
            titleVisibility: .visible
        ) {
            Button("Remove Category", role: .destructive) {
                updateCategories(to: nil)
            }

            ForEach(destinationCategories) { destination in
                Button(destination.name) {
                    updateCategories(to: destination.id)
                }
            }
        } message: {
            Text("Choose the category for the selected foods.")
        }
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private func foodRow(_ food: CatalogFood) -> some View {
        let canEdit = food.source == "user"

        Button {
            guard isSelecting, canEdit else { return }
            if selectedFoodIDs.contains(food.id) {
                selectedFoodIDs.remove(food.id)
            } else {
                selectedFoodIDs.insert(food.id)
            }
        } label: {
            HStack(spacing: 12) {
                if isSelecting {
                    Image(systemName: selectedFoodIDs.contains(food.id)
                        ? "checkmark.circle.fill"
                        : "circle")
                        .foregroundStyle(canEdit ? AppColors.accent : AppColors.textTertiary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("\(food.caloriesPer100g.formatted(.number.precision(.fractionLength(0)))) kcal per 100 g")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                if !canEdit {
                    Text("System")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isSelecting && !canEdit)
        .accessibilityLabel(food.name)
        .accessibilityHint(canEdit
            ? "Select this food to change its category."
            : "System foods can’t be moved.")
    }

    private func updateCategories(to categoryId: String?) {
        let foodIDs = selectedFoodIDs

        Task {
            guard await viewModel.assignSelectedFoods(foodIDs, to: categoryId) else {
                return
            }

            selectedFoodIDs.removeAll()
            isSelecting = false
            await onCategoriesChanged()
        }
    }
}
