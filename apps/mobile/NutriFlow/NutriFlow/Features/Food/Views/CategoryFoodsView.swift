import SwiftUI

struct CategoryFoodsView: View {
    let category: FoodCategory?
    let availableCategories: [FoodCategory]
    let onCategoriesChanged: () async -> Void
    
    @State private var categorySearchText = ""
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

    init(
        availableCategories: [FoodCategory],
        viewModel: CategoryFoodsViewModel,
        onCategoriesChanged: @escaping () async -> Void
    ) {
        self.category = nil
        self.availableCategories = availableCategories
        self.onCategoriesChanged = onCategoriesChanged
        _viewModel = State(initialValue: viewModel)
    }

    private var selectedCount: Int {
        selectedFoodIDs.count
    }

    private var destinationCategories: [FoodCategory] {
        guard let category else { return availableCategories }
        return availableCategories.filter { $0.id != category.id }
    }

    var body: some View {
        List {
            if let category {
                Section {
                    Label("\(category.foodCount) foods in this category", systemImage: "tag.fill")
                        .foregroundStyle(AppColors.textSecondary)
                }
            } else {
                Section {
                    Label("Select your foods to assign or remove a category.", systemImage: "tag.fill")
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            switch viewModel.state {
            case .idle, .loading:
                skeletonRows()

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
                    ForEach(viewModel.foods) { food in
                        foodRow(food)
                            .task {
                                await viewModel.loadMoreIfNeeded(current: food)
                            }
                    }

                    if viewModel.isLoadingMore {
                        skeletonRows(count: 2)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(category?.name ?? "Manage Foods")
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
        .sheet(isPresented: $isChoosingDestination) {
            NavigationStack {
                List {
                    Section {
                        Button(role: .destructive) {
                            isChoosingDestination = false
                            updateCategories(to: nil)
                        } label: {
                            Label("Unassign Category", systemImage: "folder.badge.minus")
                        }
                    }

                    let filteredCategories = destinationCategories.filter {
                        categorySearchText.isEmpty ||
                        $0.name.localizedCaseInsensitiveContains(categorySearchText)
                    }

                    if !filteredCategories.filter(\.isPersonal).isEmpty {
                        Section("My Categories") {
                            ForEach(filteredCategories.filter(\.isPersonal)) { destination in
                                categoryRow(destination)
                            }
                        }
                    }

                    if !filteredCategories.filter({ !$0.isPersonal }).isEmpty {
                        Section("System Categories") {
                            ForEach(filteredCategories.filter { !$0.isPersonal }) { destination in
                                categoryRow(destination)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .searchable(
                    text: $categorySearchText,
                    prompt: "Search categories"
                )
                .navigationTitle("Choose Category")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancel") {
                            isChoosingDestination = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .onDisappear {
                categorySearchText = ""
            }
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
            CategoryFoodCard(
                food: food,
                isSelecting: isSelecting,
                isSelected: selectedFoodIDs.contains(food.id)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSelecting && !canEdit)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .accessibilityHint(canEdit
            ? "Select this food to change its category."
            : "System foods can’t be moved.")
    }
    
    private func categoryRow(_ destination: FoodCategory) -> some View {
        Button {
            isChoosingDestination = false
            updateCategories(to: destination.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: destination.icon ?? "tag.fill")
                    .foregroundStyle(AppColors.accent)

                Text(destination.name)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func skeletonRows(count: Int = 6) -> some View {
        ForEach(0..<count, id: \.self) { _ in
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.surfaceSecondary)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.surfaceSecondary)
                        .frame(width: 148, height: 16)

                    HStack(spacing: 6) {
                        Capsule()
                            .fill(AppColors.surfaceSecondary)
                            .frame(width: 56, height: 18)
                        Capsule()
                            .fill(AppColors.surfaceSecondary)
                            .frame(width: 92, height: 18)
                    }

                    HStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { _ in
                            Capsule()
                                .fill(AppColors.surfaceSecondary)
                                .frame(width: 48, height: 18)
                        }
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(AppColors.surface, in: .rect(cornerRadius: AppRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(AppColors.border.opacity(0.70), lineWidth: 1)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .accessibilityHidden(true)
        }
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
