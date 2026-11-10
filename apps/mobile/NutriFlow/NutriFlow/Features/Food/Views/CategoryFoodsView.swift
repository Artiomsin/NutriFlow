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
    @State private var visibleSystemCount = 5
    @State private var isShowingMoreSystemFoods = false

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
    
    private var isSystemCategory: Bool {
        category.map { !$0.isPersonal } ?? false
    }

    private var personalFoods: [CatalogFood] {
        viewModel.foods.filter { $0.source == "user" }
    }

    private var systemFoods: [CatalogFood] {
        viewModel.foods.filter { $0.source != "user" }
    }

    private var visibleSystemFoods: [CatalogFood] {
        Array(systemFoods.prefix(visibleSystemCount))
    }

    private var canShowMoreSystemFoods: Bool {
        !systemFoods.isEmpty
    }

    private var destinationCategories: [FoodCategory] {
        guard let category else { return availableCategories }
        return availableCategories.filter { $0.id != category.id }
    }

    // MARK: - Header blocks

    @ViewBuilder
    private func categoryHeader(_ category: FoodCategory) -> some View {
        let categoryColor: Color = Color(hex: category.color ?? "#10B981") ?? AppColors.accent

        HStack(spacing: 16) {
            // Category icon — large circle on left
            CategoryIconView(
                iconName: category.icon ?? FoodCategoryIcons.defaultIcon,
                color: categoryColor
            )
            .frame(width: 48, height: 48)
            .background(categoryColor.opacity(0.12))
            .clipShape(.circle)

            // Name + count (center)
            VStack(alignment: .leading, spacing: 5) {
                Text(category.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Image(systemName: "cart.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppColors.textSecondary.opacity(0.6))

                    Text("\(category.foodCount) foods")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer(minLength: 0)

            // Right badge — compact food count pill
            VStack(alignment: .center, spacing: 3) {
                Text("\(category.foodCount)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(categoryColor)
                    .minimumScaleFactor(0.6)

                Text("foods")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(categoryColor.opacity(0.6))
            }
            .frame(width: 48)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(categoryColor.opacity(0.06), in: .rect(cornerRadius: AppRadius.large))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .stroke(categoryColor, lineWidth: 1.5)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface, in: .rect(cornerRadius: AppRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.large)
                .stroke(categoryColor, lineWidth: 2)
        }
        .shadow(color: categoryColor.opacity(0.08), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var manageAllHeader: some View {
        HStack(spacing: 16) {
            // Category icon — large circle on left
            Image(systemName: "tag.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 48, height: 48)
                .background(AppColors.accent.opacity(0.12))
                .clipShape(.circle)

            // Name + subtitle (center)
            VStack(alignment: .leading, spacing: 5) {
                Text("Manage Dishes")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                Text("Select your foods to assign or remove a category.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface, in: .rect(cornerRadius: AppRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.large)
                .stroke(AppColors.accent, lineWidth: 2)
        }
        .shadow(color: AppColors.accent.opacity(0.08), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 2)
    }

    // MARK: - Show more / Show less button

    @ViewBuilder
    private var showMoreButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                if isShowingMoreSystemFoods {
                    visibleSystemCount = 5
                    isShowingMoreSystemFoods = false
                } else {
                    visibleSystemCount = systemFoods.count
                    isShowingMoreSystemFoods = true
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isShowingMoreSystemFoods ? "chevron.up" : "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.accent)

                Text(
                    isShowingMoreSystemFoods
                        ? "Show less (\(systemFoods.count) total)"
                        : "Show more (\(systemFoods.count - visibleSystemCount) more)"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.accent)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(AppColors.accent.opacity(0.08), in: .rect(cornerRadius: AppRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(AppColors.accent, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    var body: some View {
        List {
            // Category header — красивый блок с количеством блюд
            Section {
                if let category {
                    categoryHeader(category)
                } else {
                    manageAllHeader
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

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
                } else if isSystemCategory {
                    if !personalFoods.isEmpty {
                        Section("Personal") {
                            ForEach(personalFoods) { food in
                                foodRow(food)
                            }
                        }
                    }

                    Section("System") {
                        if visibleSystemFoods.isEmpty {
                            Text("No system foods in this category.")
                                .foregroundStyle(AppColors.textSecondary)
                        } else {
                            ForEach(visibleSystemFoods) { food in
                                systemFoodRow(food)
                            }
                        }

                        if canShowMoreSystemFoods {
                            showMoreButton
                        }
                    }

                    if viewModel.isLoadingMore {
                        skeletonRows(count: 2)
                    }

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
        .listStyle(.plain)
        .listRowSpacing(16)
        .listSectionSpacing(16)
        .contentMargins(.horizontal, 16)
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

    private func systemFoodRow(_ food: CatalogFood) -> some View {
        CategoryFoodCard(
            food: food,
            isSelecting: false,
            isSelected: false
        )
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func foodRow(_ food: CatalogFood) -> some View {
        let canEdit = food.source == "user"

        Button {
            guard canEdit else { return }

            if selectedFoodIDs.contains(food.id) {
                selectedFoodIDs.remove(food.id)
            } else {
                selectedFoodIDs.insert(food.id)
            }

            isSelecting = !selectedFoodIDs.isEmpty
        } label: {
            CategoryFoodCard(
                food: food,
                isSelecting: isSelecting,
                isSelected: selectedFoodIDs.contains(food.id)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canEdit)
        .listRowInsets(EdgeInsets())
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
