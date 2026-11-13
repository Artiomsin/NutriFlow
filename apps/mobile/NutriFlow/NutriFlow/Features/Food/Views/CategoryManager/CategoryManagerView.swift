import SwiftUI

/// Category Manager: search, create, edit, delete food categories.
struct CategoryManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AddFoodViewModel

    @State private var categoryToDelete: FoodCategory?
    @State private var categoryToEdit: FoodCategory?
    @State private var categoryToManage: FoodCategory?
    @State private var isManagingAllPersonalDishes = false
    @State private var allPersonalDishesVM: CategoryFoodsViewModel?
    @State private var isShowingAllSystemCategories = false
    @State private var categorySearchText = ""
    @State private var searchScope: SearchScope = .all

    private var personalCategories: [FoodCategory] {
        viewModel.categories.filter(\.isPersonal)
    }

    private var systemCategories: [FoodCategory] {
        viewModel.categories.filter { !$0.isPersonal }
    }

    /// Whether personal categories are visible under the current scope.
    private var showPersonalScope: Bool {
        searchScope != .system
    }

    /// Whether system categories are visible under the current scope.
    private var showSystemScope: Bool {
        searchScope != .personal
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

    private var hasPersonalResults: Bool {
        showPersonalScope && !filteredPersonalCategories.isEmpty
    }

    private var hasSystemResults: Bool {
        showSystemScope && !filteredSystemCategories.isEmpty
    }

    private var hasAnyResults: Bool {
        hasPersonalResults || hasSystemResults
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    IntroductionCard()

                    if viewModel.isLoadingCategories && viewModel.categories.isEmpty {
                        LoadingCard()
                    } else if let error = viewModel.categoriesError {
                        ErrorView(error: error) {
                            viewModel.retryCategories()
                        }
                    } else {
                        CreateCategoryCardView(
                            errorMessage: viewModel.categoryNameError,
                            onNameChanged: viewModel.clearCategoryNameError
                        ) { name, icon, color in
                            await viewModel.createCategory(named: name, icon: icon, color: color) != nil
                        }

                        ManagePersonalDishesCard {
                            isManagingAllPersonalDishes = true
                        }

                        if !personalCategories.isEmpty || !systemCategories.isEmpty {
                            CategorySearchBar(
                                searchText: $categorySearchText,
                                scope: $searchScope
                            )

                            // Global empty state when searching and nothing found anywhere
                            if !categorySearchText.isEmpty && !hasAnyResults {
                                CategoryEmptySearchState()
                            } else {
                                // Show only scopes that have results when searching;
                                // when search is empty, show both scopes normally.
                                if showPersonalScope && (!categorySearchText.isEmpty ? hasPersonalResults : true) {
                                    CategorySectionView(
                                        title: "Your Categories",
                                        subtitle: "Only you can edit or delete these.",
                                        categories: filteredPersonalCategories,
                                        isPersonal: true,
                                        countBadge: categorySearchText.isEmpty ? nil : filteredPersonalCategories.count,
                                        onSelect: { categoryToManage = $0 },
                                        onEdit: { categoryToEdit = $0 },
                                        onDelete: { categoryToDelete = $0 }
                                    )
                                }

                                if showSystemScope && (!categorySearchText.isEmpty ? hasSystemResults : true) {
                                    CategorySectionView(
                                        title: "System Categories",
                                        subtitle: "\(systemCategories.count) available to everyone",
                                        categories: filteredSystemCategories,
                                        isPersonal: false,
                                        countBadge: categorySearchText.isEmpty ? nil : filteredSystemCategories.count,
                                        trailingContent: {
                                            if categorySearchText.isEmpty && systemCategories.count > 5 {
                                                systemToggleButton
                                            }
                                        },
                                        onSelect: { categoryToManage = $0 },
                                        onEdit: { _ in },
                                        onDelete: { _ in }
                                    )
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

    /// "Show all / Less" toggle for system categories (only when search is empty).
    private var systemToggleButton: some View {
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
