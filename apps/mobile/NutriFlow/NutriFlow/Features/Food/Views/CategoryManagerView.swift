import SwiftUI

struct CategoryManagerView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: AddFoodViewModel

    @State private var categoryName = ""
    @State private var selectedIcon = FoodCategoryIcons.defaultIcon
    @State private var categoryToDelete: FoodCategory?
    @State private var categoryToEdit: FoodCategory?
    @State private var categoryToManage: FoodCategory?
    @State private var isManagingAllPersonalDishes = false
    @State private var areSystemCategoriesExpanded = false

    private var personalCategories: [FoodCategory] {
        viewModel.categories.filter(\.isPersonal)
    }

    private var systemCategories: [FoodCategory] {
        viewModel.categories.filter { !$0.isPersonal }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    introductionCard

                    if viewModel.isLoadingCategories &&
                        viewModel.categories.isEmpty {
                        loadingCard
                    } else if let error = viewModel.categoriesError {
                        ErrorView(error: error) {
                            viewModel.retryCategories()
                        }
                    } else {
                        createCategoryCard
                        managePersonalDishesCard

                        if !personalCategories.isEmpty {
                            categorySection(
                                title: "Your Categories",
                                subtitle: "Only you can edit or delete these.",
                                categories: personalCategories,
                                showsDeleteAction: true
                            )
                        }

                        systemCategoriesSection
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
            .confirmationDialog(
                "Delete category?",
                item: $categoryToDelete,
                titleVisibility: .visible
            ) { category in
                Button(
                    "Delete \(category.name)",
                    role: .destructive
                ) {
                    Task {
                        await viewModel.deleteCategory(category)
                    }
                }
            } message: { _ in
                Text(
                    "The category will be removed from your foods. Your foods will remain without a category."
                )
            }
            .sheet(item: $categoryToEdit) { category in
                CategoryEditorView(
                    category: category,
                    viewModel: viewModel
                )
            }
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
                        viewModel: viewModel.makeAllPersonalDishesViewModel(),
                        onCategoriesChanged: {
                            await viewModel.refreshAfterCategoryChange()
                        }
                    )
                }
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
                    icons: FoodCategoryIcons.all
                )

                Button(
                    "Add Category",
                    systemImage: "plus",
                    action: createCategory
                )
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accent)
                .disabled(trimmedCategoryName.isEmpty)
            }
        }
    }

    private var trimmedCategoryName: String {
        categoryName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }


    private var systemCategoriesSection: some View {
        AppCard {
            DisclosureGroup(
                isExpanded: $areSystemCategoriesExpanded
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(systemCategories) { category in
                        categoryRow(
                            category,
                            showsDeleteAction: false
                        )
                    }
                }
                .padding(.top, 12)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2.fill")
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(AppColors.surfaceSecondary)
                        .clipShape(.circle)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("System Categories")
                            .font(.headline)
                            .foregroundStyle(AppColors.textPrimary)

                        Text(
                            "\(systemCategories.count) available to everyone"
                        )
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            .tint(AppColors.accent)
        }
    }


    @ViewBuilder
    private func categorySection(
        title: String,
        subtitle: String,
        categories: [FoodCategory],
        showsDeleteAction: Bool
    ) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }

                if categories.isEmpty {
                    Text("No categories yet.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    ForEach(categories) { category in
                        categoryRow(
                            category,
                            showsDeleteAction: showsDeleteAction
                        )
                    }
                }
            }
        }
    }



    private func categoryRow(
        _ category: FoodCategory,
        showsDeleteAction: Bool
    ) -> some View {
        HStack(spacing: 8) {
            CategoryIconView(
                iconName: category.icon ?? FoodCategoryIcons.defaultIcon,
                color: AppColors.accent
            )
            .frame(width: 28, height: 28)
            .padding(6)
            .background(AppColors.accent.opacity(0.12))
            .clipShape(.circle)

            Button(category.name) {
                if category.isPersonal {
                    categoryToEdit = category
                }
            }
            .buttonStyle(.plain)
            .font(.body.weight(.medium))
            .foregroundStyle(AppColors.textPrimary)

            Spacer()

            Text("\(category.foodCount)")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)
                .accessibilityLabel("\(category.foodCount) foods")

            Button("Manage dishes", systemImage: "list.bullet") {
                categoryToManage = category
            }
            .labelStyle(.iconOnly)
            .foregroundStyle(AppColors.accent)
            .accessibilityLabel("Manage dishes in \(category.name)")

            if showsDeleteAction {
                Button(
                    "Delete",
                    systemImage: "trash",
                    role: .destructive
                ) {
                    categoryToDelete = category
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel("Delete \(category.name)")
            } else {
                Text("System")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(AppColors.surfaceSecondary)
                    .clipShape(.capsule)
            }
        }
        .padding(.vertical, 4)
    }



    private func createCategory() {
        let name = trimmedCategoryName

        guard !name.isEmpty else { return }

        let icon = selectedIcon

        categoryName = ""
        selectedIcon = FoodCategoryIcons.defaultIcon

        Task {
            await viewModel.createCategory(
                named: name,
                icon: icon
            )
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
        FoodCategory(id: "personal-breakfast", name: "My Breakfast", icon: "sunrise.fill", createdBy: "user-1", createdAt: "2026-05-18T08:00:00Z", foodCount: 3),
        FoodCategory(id: "personal-home", name: "Home Cooking", icon: "house.fill", createdBy: "user-1", createdAt: "2026-05-18T09:00:00Z", foodCount: 5),
        FoodCategory(id: "personal-snacks", name: "Snacks", icon: "popcorn", createdBy: "user-1", createdAt: "2026-05-18T10:00:00Z", foodCount: 2),
        FoodCategory(id: "system-fruits", name: "Fruits", icon: "leaf.fill", createdBy: nil, createdAt: "2026-01-01T00:00:00Z", foodCount: 2),
        FoodCategory(id: "system-protein", name: "Protein", icon: "fish.fill", createdBy: nil, createdAt: "2026-01-01T00:00:00Z", foodCount: 1),
        FoodCategory(id: "system-dairy", name: "Dairy", icon: "cup.and.saucer.fill", createdBy: nil, createdAt: "2026-01-01T00:00:00Z", foodCount: 1)
    ]

    return CategoryManagerView(viewModel: viewModel)
}
