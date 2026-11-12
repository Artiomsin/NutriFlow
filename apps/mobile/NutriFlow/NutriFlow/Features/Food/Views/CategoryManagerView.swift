import SwiftUI

struct CategoryManagerView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: AddFoodViewModel

    @State private var categoryName = ""
    @State private var selectedIcon = FoodCategoryIcons.defaultIcon
    @State private var selectedColor: Color = Color(hex: "#10B981") ?? AppColors.accent
    @State private var categoryToDelete: FoodCategory?
    @State private var categoryToEdit: FoodCategory?
    @State private var categoryToManage: FoodCategory?
    @State private var isManagingAllPersonalDishes = false
    @State private var allPersonalDishesVM: CategoryFoodsViewModel?
    @State private var isShowingAllSystemCategories = false
    @State private var categorySearchText = ""
    @State private var searchScope: SearchScope = .all

    /// Which category scopes are currently visible based on the selected search scope.
    private var showPersonalScope: Bool {
        searchScope != .system
    }

    private var showSystemScope: Bool {
        searchScope != .personal
    }

    /// Whether the personal categories section has any results to display.
    private var hasPersonalResults: Bool {
        showPersonalScope && !filteredPersonalCategories.isEmpty
    }

    /// Whether the system categories section has any results to display.
    private var hasSystemResults: Bool {
        showSystemScope && !filteredSystemCategories.isEmpty
    }

    /// Whether any results are shown across all visible scopes.
    private var hasAnyResults: Bool {
        hasPersonalResults || hasSystemResults
    }

    private var personalCategories: [FoodCategory] {
        viewModel.categories.filter(\.isPersonal)
    }

    private var systemCategories: [FoodCategory] {
        viewModel.categories.filter { !$0.isPersonal }
    }

    private var filteredPersonalCategories: [FoodCategory] {
        guard showPersonalScope else { return [] }
        return personalCategories.filter {
            categorySearchText.isEmpty || $0.name.localizedCaseInsensitiveContains(categorySearchText)
        }
    }

    private var filteredSystemCategories: [FoodCategory] {
        guard showSystemScope else { return [] }
        let filtered = systemCategories.filter {
            categorySearchText.isEmpty || $0.name.localizedCaseInsensitiveContains(categorySearchText)
        }
        // When searching, show all matches; otherwise respect the "first 5" limit
        if !categorySearchText.isEmpty || isShowingAllSystemCategories {
            return filtered
        }
        return Array(filtered.prefix(5))
    }

    private var displayedSystemCategories: [FoodCategory] {
        isShowingAllSystemCategories ? filteredSystemCategories : Array(filteredSystemCategories.prefix(5))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    introductionCard

                    if viewModel.isLoadingCategories && viewModel.categories.isEmpty {
                        loadingCard
                    } else if let error = viewModel.categoriesError {
                        ErrorView(error: error) {
                            viewModel.retryCategories()
                        }
                    } else {
                        createCategoryCard
                        managePersonalDishesCard

                        if !personalCategories.isEmpty || !systemCategories.isEmpty {
                            categorySearchBar

                            // Global empty state when searching and nothing found anywhere
                            if !categorySearchText.isEmpty && !hasAnyResults {
                                emptySearchState
                            } else {
                                // Show only scopes that have results when searching;
                                // when search is empty, show both scopes normally.
                                if showPersonalScope && (!categorySearchText.isEmpty ? hasPersonalResults : true) {
                                    personalCategoriesStack
                                }

                                if showSystemScope && (!categorySearchText.isEmpty ? hasSystemResults : true) {
                                    systemCategoriesStack
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(AppColors.accent)
                }
            }
            .task {
                await viewModel.loadCategories()
            }
            .sheet(item: $categoryToEdit) { category in
                CategoryEditorView(category: category, viewModel: viewModel)
                    .presentationDetents([.large])
            }
            .animation(.easeInOut(duration: 0.2), value: categoryToDelete)
            .sheet(item: $categoryToManage) { category in
                NavigationStack {
                    CategoryFoodsView(
                        category: category,
                        availableCategories: viewModel.categories,
                        viewModel: viewModel.makeCategoryFoodsViewModel(for: category),
                        onCategoriesChanged: {
                            await viewModel.refreshAfterCategoryChange()
                        }
                    )
                }
            }
            .sheet(isPresented: $isManagingAllPersonalDishes) {
                NavigationStack {
                    CategoryFoodsView(
                        availableCategories: viewModel.categories,
                        viewModel: allPersonalDishesVM ?? viewModel.makeAllPersonalDishesViewModel(),
                        onCategoriesChanged: {
                            await viewModel.refreshAfterCategoryChange()
                            await allPersonalDishesVM?.load()
                        }
                    )
                    .onAppear {
                        if allPersonalDishesVM == nil {
                            allPersonalDishesVM = viewModel.makeAllPersonalDishesViewModel()
                        }
                        Task { await allPersonalDishesVM?.load() }
                    }
                }
            }
            .overlay(alignment: .center) {
                if let category = categoryToDelete {
                    DeleteCategoryModal(
                        category: category,
                        onDelete: {
                            categoryToDelete = nil
                            Task {
                                await viewModel.deleteCategory(category)
                            }
                        },
                        onCancel: {
                            categoryToDelete = nil
                        }
                    )
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: categoryToDelete)
            .alert(
                "Couldn’t save category",
                isPresented: Binding(
                    get: { viewModel.categoryMutationError != nil },
                    set: { if !$0 { viewModel.categoryMutationError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    viewModel.categoryMutationError = nil
                }
            } message: {
                Text("Your changes weren’t saved. Please try again.")
            }
        }
    }

    private var introductionCard: some View {
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

    private var managePersonalDishesCard: some View {
        AppCard {
            Button("Manage Personal Dishes", systemImage: "square.and.pencil") {
                isManagingAllPersonalDishes = true
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(AppColors.accent)
            .accessibilityHint("Select personal dishes and assign or remove categories.")
        }
    }

    private var loadingCard: some View {
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

    private var createCategoryCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Create a Category")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)

                TextField(
                    "For example, Homemade meals",
                    text: $categoryName
                )
                .font(.body)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .frame(height: 48)
                .padding(.horizontal, 12)
                .background(AppColors.surfaceSecondary)
                .clipShape(.rect(cornerRadius: AppRadius.medium))

                CategoryIconPicker(
                    selection: $selectedIcon,
                    icons: FoodCategoryIcons.all,
                    color: selectedColor
                )

                // Color picker (gradient bar)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)

                    GradientColorPicker(selectedColor: $selectedColor)
                }

                Button("Add Category", systemImage: "plus", action: createCategory)
                    .buttonStyle(.borderedProminent)
                    .tint(selectedColor)
                    .disabled(trimmedCategoryName.isEmpty)
            }
        }
    }

    private var trimmedCategoryName: String {
        categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var categorySearchBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Search categories", text: $categorySearchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(height: 48)
                .padding(.horizontal, 12)
                .background(AppColors.surfaceSecondary)
                .clipShape(.rect(cornerRadius: AppRadius.medium))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(AppColors.border, lineWidth: 1)
                }

            SearchScopePicker(
                selection: $searchScope
            )
        }
    }

    /// Scope toggle buttons for filtering categories by All / Personal / System.
    private struct SearchScopePicker: View {
        @Binding var selection: SearchScope

        var body: some View {
            HStack(spacing: 8) {
                ForEach(SearchScope.allCases, id: \.self) { scope in
                    Button {
                        selection = scope
                    } label: {
                        Text(scope.displayTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selection == scope ? .white : AppColors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                selection == scope
                                ? AppColors.accent
                                : AppColors.surfaceSecondary,
                                in: .rect(cornerRadius: AppRadius.medium)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                    .stroke(
                                        selection == scope ? Color.clear : AppColors.accent.opacity(0.4),
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Scope: \(scope.displayTitle)"))
                    .accessibilityAddTraits(selection == scope ? .isSelected : [])
                }
            }
        }
    }

    /// Search scope options for filtering categories.
    enum SearchScope: String, CaseIterable {
        case all, personal, system

        var displayTitle: String {
            switch self {
            case .all: return "All"
            case .personal: return "Personal"
            case .system: return "System"
            }
        }
    }

    /// Empty state shown when search is active but nothing matches.
    private var emptySearchState: some View {
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

    private var personalCategoriesStack: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Text("Your Categories")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)

                if !categorySearchText.isEmpty {
                    Text("(\(filteredPersonalCategories.count))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }

            Text("Only you can edit or delete these.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)

            VStack(spacing: 10) {
                ForEach(filteredPersonalCategories) { category in
                    categoryStackCell(
                        category,
                        isPersonal: true
                    )
                }
            }
        }
    }

    private var systemCategoriesStack: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Text("System Categories")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)

                if !categorySearchText.isEmpty {
                    Text("(\(filteredSystemCategories.count))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.textTertiary)
                } else if systemCategories.count > 5 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isShowingAllSystemCategories.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isShowingAllSystemCategories ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.bold))
                            Text(
                                isShowingAllSystemCategories
                                    ? "Less"
                                    : "All (\(systemCategories.count))"
                            )
                            .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(AppColors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(AppColors.accent.opacity(0.10), in: .rect(cornerRadius: AppRadius.medium))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .stroke(AppColors.accent.opacity(0.30), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("\(systemCategories.count) available to everyone")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)

            VStack(spacing: 10) {
                ForEach(displayedSystemCategories) { category in
                    categoryStackCell(
                        category,
                        isPersonal: false
                    )
                }
            }
        }
    }

    private func categoryStackCell(
        _ category: FoodCategory,
        isPersonal: Bool
    ) -> some View {
        let categoryColor: Color = Color(hex: category.color ?? "#10B981") ?? AppColors.accent

        return HStack(spacing: 12) {
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
                    Button {
                        categoryToEdit = category
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColors.accent)
                            .padding(8)
                            .background(AppColors.accent.opacity(0.1), in: .circle)
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        categoryToDelete = category
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColors.error)
                            .padding(8)
                            .background(AppColors.error.opacity(0.1), in: .circle)
                    }
                    .buttonStyle(.plain)
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
            categoryToManage = category
        }
    }

    private func createCategory() {
        let name = trimmedCategoryName
        guard !name.isEmpty else { return }

        let icon = selectedIcon
        let color = selectedColor.toHex() ?? "#10B981"
        categoryName = ""
        selectedIcon = FoodCategoryIcons.defaultIcon
        selectedColor = Color(hex: "#10B981") ?? AppColors.accent

        Task {
            await viewModel.createCategory(named: name, icon: icon, color: color)
        }
    }
}

private struct DeleteCategoryModal: View {
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

#Preview("Category Manager") {
    let viewModel = AddFoodViewModel(
        service: MockFoodService(),
        coordinator: nil,
        todayFoodVM: TodayFoodViewModel(
            service: MockFoodService(),
            coordinator: nil
        )
    )
    viewModel.categories = [
        FoodCategory(id: "system-fruits", name: "Fruits", icon: "leaf.fill", color: "#84CC16", createdBy: nil, createdAt: "2026-01-01T00:00:00Z", foodCount: 5),
        FoodCategory(id: "system-protein", name: "Protein", icon: "fish.fill", color: "#EF4444", createdBy: nil, createdAt: "2026-01-01T00:00:00Z", foodCount: 4),
        FoodCategory(id: "system-dairy", name: "Dairy", icon: "cup.and.saucer.fill", color: "#3B82F6", createdBy: nil, createdAt: "2026-01-01T00:00:00Z", foodCount: 3),
        FoodCategory(id: "system-vegetables", name: "Vegetables", icon: "carrot.fill", color: "#F59E0B", createdBy: nil, createdAt: "2026-01-01T00:00:00Z", foodCount: 3),
        FoodCategory(id: "system-grains", name: "Grains", icon: "bread.fill", color: "#A855F7", createdBy: nil, createdAt: "2026-01-01T00:00:00Z", foodCount: 3),
        FoodCategory(id: "system-snacks", name: "Snacks", icon: "takeoutbag.and.cup.and.straw", color: "#EC4899", createdBy: nil, createdAt: "2026-01-01T00:00:00Z", foodCount: 2),
        FoodCategory(id: "system-beverages", name: "Beverages", icon: "cup.fill", color: "#06B6D4", createdBy: nil, createdAt: "2026-01-01T00:00:00Z", foodCount: 2),
        FoodCategory(id: "personal-breakfast", name: "Breakfast", icon: "sunrise.fill", color: "#F97316", createdBy: "user-1", createdAt: "2026-05-18T08:00:00Z", foodCount: 3),
        FoodCategory(id: "personal-home", name: "Home Cooking", icon: "house.fill", color: "#10B981", createdBy: "user-1", createdAt: "2026-05-18T08:00:00Z", foodCount: 4),
        FoodCategory(id: "personal-dinner", name: "Dinner", icon: "moon.fill", color: "#6366F1", createdBy: "user-1", createdAt: "2026-05-18T09:00:00Z", foodCount: 2),
        FoodCategory(id: "personal-drinks", name: "Drinks", icon: "cup.and.saucer.fill", color: "#EC4899", createdBy: "user-1", createdAt: "2026-05-18T10:00:00Z", foodCount: 2)
    ]

    return CategoryManagerView(viewModel: viewModel)
}
