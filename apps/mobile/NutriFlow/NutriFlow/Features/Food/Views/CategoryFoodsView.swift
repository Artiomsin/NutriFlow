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
    @State private var isShowingMoreSystemFoods = false

    /// Number of system foods shown while the section is collapsed.
    private static let collapsedSystemFoodLimit = 5

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

    // Categories are reloaded after a move. Resolve the current value by ID so
    // the header and counters never keep showing the snapshot from sheet launch.
    private var displayedCategory: FoodCategory? {
        guard let category else { return nil }
        return availableCategories.first { $0.id == category.id } ?? category
    }
    
    private var isSystemCategory: Bool {
        displayedCategory.map { !$0.isPersonal } ?? false
    }

    private var categoryAccentColor: Color {
        guard let category = displayedCategory else { return AppColors.accent }
        return Color(hex: category.color ?? "#10B981") ?? AppColors.accent
    }

    private var personalFoods: [CatalogFood] {
        viewModel.foods.filter { $0.source == "user" }
    }

    private var systemFoods: [CatalogFood] {
        viewModel.foods.filter { $0.source != "user" }
    }

    private var visibleSystemFoods: [CatalogFood] {
        isShowingMoreSystemFoods
            ? systemFoods
            : Array(systemFoods.prefix(Self.collapsedSystemFoodLimit))
    }

    private var categoriesByID: [String: FoodCategory] {
        Dictionary(uniqueKeysWithValues: availableCategories.map { ($0.id, $0) })
    }

    private var personalFoodGroups: [PersonalFoodCategoryGroup] {
        guard category == nil else { return [] }

        let personalCategoryIDs = Set(
            availableCategories.filter(\.isPersonal).map(\.id)
        )
        let systemCategoryIDs = Set(
            availableCategories.filter { !$0.isPersonal }.map(\.id)
        )

        let uncategorizedFoods = personalFoods.filter { $0.categoryId == nil }
        let foodsInPersonalCategories = personalFoods.filter {
            guard let categoryID = $0.categoryId else { return false }
            return personalCategoryIDs.contains(categoryID)
        }
        let foodsInSystemCategories = personalFoods.filter {
            guard let categoryID = $0.categoryId else { return false }
            // Foods whose category is no longer available stay visible here
            // instead of disappearing from the manager.
            return systemCategoryIDs.contains(categoryID) ||
                (!personalCategoryIDs.contains(categoryID) && !systemCategoryIDs.contains(categoryID))
        }

        return [
            PersonalFoodCategoryGroup(
                id: "uncategorized",
                title: "Uncategorized",
                icon: "folder.badge.minus",
                color: AppColors.accent,
                foods: uncategorizedFoods
            ),
            PersonalFoodCategoryGroup(
                id: "personal-categories",
                title: "Personal Categories",
                icon: "person.fill",
                color: AppColors.accent,
                foods: foodsInPersonalCategories
            ),
            PersonalFoodCategoryGroup(
                id: "system-categories",
                title: "System Categories",
                icon: "globe",
                color: AppColors.textSecondary,
                foods: foodsInSystemCategories
            )
        ]
        .filter { !$0.foods.isEmpty }
    }

    /// The toggle must stay available once the section is expanded, otherwise
    /// there is no way back to the collapsed list.
    private var canShowMoreSystemFoods: Bool {
        systemFoods.count > Self.collapsedSystemFoodLimit
    }

    private var destinationCategories: [FoodCategory] {
        guard let category else { return availableCategories }
        return availableCategories.filter { $0.id != category.id }
    }

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
                        .foregroundStyle(categoryColor)

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


    @ViewBuilder
    private var showMoreButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                isShowingMoreSystemFoods.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isShowingMoreSystemFoods ? "chevron.up" : "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(categoryAccentColor)

                Text(
                    isShowingMoreSystemFoods
                        ? "Show less (\(systemFoods.count) total)"
                        : "Show more (\(max(systemFoods.count - Self.collapsedSystemFoodLimit, 0)) more)"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(categoryAccentColor)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(categoryAccentColor.opacity(0.08), in: .rect(cornerRadius: AppRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(categoryAccentColor, lineWidth: 1.5)
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
                if let category = displayedCategory {
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
                    .frame(maxWidth: .infinity, minHeight: 280)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
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
                                    .task {
                                        guard isShowingMoreSystemFoods,
                                              food.id == systemFoods.last?.id else { return }
                                        await viewModel.loadMoreSystemFoods()
                                    }
                            }
                        }

                        if canShowMoreSystemFoods {
                            showMoreButton
                        }
                    }

                    if viewModel.isLoadingMore {
                        skeletonRows(count: 2)
                    }

                } else if category == nil {
                    ForEach(personalFoodGroups) { group in
                        PersonalFoodCategorySection(
                            group: group,
                            categoriesByID: categoriesByID,
                            isSelecting: isSelecting,
                            selectedFoodIDs: selectedFoodIDs,
                            loadsMoreWhenVisible: group.id == personalFoodGroups.last?.id,
                            onToggleSelection: toggleSelection,
                            onReachEnd: {
                                Task {
                                    await viewModel.loadMore()
                                }
                            }
                        )
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
        .animation(.easeOut(duration: 0.25), value: viewModel.state)
        .animation(.easeOut(duration: 0.2), value: viewModel.isLoadingMore)
        .listRowSpacing(16)
        .listSectionSpacing(16)
        .contentMargins(.horizontal, 16)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(displayedCategory?.name ?? "Manage Foods")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isSelecting {
                    Button("Cancel") {
                        selectedFoodIDs.removeAll()
                        isSelecting = false
                    }
                    .tint(categoryAccentColor)
                }
            }

            if isSelecting, selectedCount > 0 {
                ToolbarItem(placement: .bottomBar) {
                    Button("Change Category") {
                        isChoosingDestination = true
                    }
                    .disabled(viewModel.isUpdating)
                    .tint(categoryAccentColor)
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
            isSelected: false,
            accentColor: categoryAccentColor
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
            toggleSelection(food)
        } label: {
            CategoryFoodCard(
                food: food,
                isSelecting: isSelecting,
                isSelected: selectedFoodIDs.contains(food.id),
                accentColor: categoryAccentColor
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
    
    private func toggleSelection(_ food: CatalogFood) {
        guard food.source == "user" else { return }

        if selectedFoodIDs.contains(food.id) {
            selectedFoodIDs.remove(food.id)
        } else {
            selectedFoodIDs.insert(food.id)
        }

        isSelecting = !selectedFoodIDs.isEmpty
    }

    private func categoryRow(_ destination: FoodCategory) -> some View {
        let categoryColor: Color = Color(hex: destination.color ?? "#10B981") ?? AppColors.accent

        return Button {
            isChoosingDestination = false
            updateCategories(to: destination.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: destination.icon ?? "tag.fill")
                    .foregroundStyle(categoryColor)
                    .frame(width: 32, height: 32)
                    .background(categoryColor.opacity(0.12), in: .circle)

                Text(destination.name)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(10)
            .background(categoryColor.opacity(0.06), in: .rect(cornerRadius: AppRadius.small))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.small)
                    .stroke(categoryColor.opacity(0.25), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func skeletonRows(count: Int = 6) -> some View {
        ForEach(0..<count, id: \.self) { _ in
            CategoryFoodSkeletonRow(showsSelection: isSelecting)
            .transition(.opacity)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
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
private struct PersonalFoodCategoryGroup: Identifiable {
    let id: String
    let title: String
    let icon: String
    let color: Color
    let foods: [CatalogFood]
}

private struct PersonalFoodCategorySection: View {
    let group: PersonalFoodCategoryGroup
    let categoriesByID: [String: FoodCategory]
    let isSelecting: Bool
    let selectedFoodIDs: Set<String>
    let loadsMoreWhenVisible: Bool
    let onToggleSelection: (CatalogFood) -> Void
    let onReachEnd: () -> Void

    var body: some View {
        Section {
            ForEach(group.foods) { food in
                Button {
                    onToggleSelection(food)
                } label: {
                    let category = food.categoryId.flatMap { categoriesByID[$0] }
                    let categoryColor = category.flatMap {
                        Color(hex: $0.color ?? "#10B981")
                    } ?? group.color

                    CategoryFoodCard(
                        food: food,
                        isSelecting: isSelecting,
                        isSelected: selectedFoodIDs.contains(food.id),
                        accentColor: categoryColor,
                        showsCategory: true,
                        categoryDisplayName: category?.name,
                        categoryIcon: category?.icon,
                        categoryColor: categoryColor
                    )
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .accessibilityHint("Select this food to change its category.")
                .task {
                    guard loadsMoreWhenVisible, food.id == group.foods.last?.id else {
                        return
                    }
                    onReachEnd()
                }
            }
        } header: {
            Label(group.title, systemImage: group.icon)
                .foregroundStyle(group.color)
        }
    }
}

