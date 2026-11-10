import SwiftUI

struct CategoryManagerView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var viewModel: AddFoodViewModel

    @State private var categoryName = ""
    @State private var selectedIcon = FoodCategoryIcons.defaultIcon
    @State private var selectedColor = "#10B981"
    @State private var categoryToDelete: FoodCategory?
    @State private var categoryToEdit: FoodCategory?
    @State private var categoryToManage: FoodCategory?
    @State private var isManagingAllPersonalDishes = false

    private var createColor: Color {
        Color(hex: selectedColor) ?? AppColors.accent
    }

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

                    if viewModel.isLoadingCategories && viewModel.categories.isEmpty {
                        loadingCard
                    } else if let error = viewModel.categoriesError {
                        ErrorView(error: error) {
                            viewModel.retryCategories()
                        }
                    } else {
                        createCategoryCard
                        managePersonalDishesCard

                        if !personalCategories.isEmpty {
                            personalCategoriesStack
                        }

                        if !systemCategories.isEmpty {
                            systemCategoriesStack
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
                        viewModel: viewModel.makeAllPersonalDishesViewModel(),
                        onCategoriesChanged: {
                            await viewModel.refreshAfterCategoryChange()
                        }
                    )
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

                // Icon + color preview
                HStack(spacing: 12) {
                    CategoryIconView(
                        iconName: selectedIcon,
                        color: createColor
                    )
                    .frame(width: 44, height: 44)
                    .background(createColor.opacity(0.12))
                    .clipShape(.circle)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedIcon.replacingOccurrences(of: ".", with: " ").capitalized)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.textSecondary)

                        Text("\(createColor.description)")
                            .font(.caption2)
                            .foregroundStyle(AppColors.textTertiary)
                    }

                    Spacer()
                }

                CategoryIconPicker(
                    selection: $selectedIcon,
                    icons: FoodCategoryIcons.all
                )

                // Color picker (preset colors)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)

                    let presetColors: [String] = [
                        "#10B981", "#EF4444", "#3B82F6", "#F59E0B",
                        "#EC4899", "#84CC16", "#A855F7", "#06B6D4",
                        "#F97316", "#6366F1", "#14B8A6", "#8B5CF6",
                    ]

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                        ForEach(presetColors, id: \.self) { hex in
                            Button {
                                selectedColor = hex
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: hex) ?? AppColors.accent)
                                        .frame(width: 32, height: 32)

                                    if selectedColor == hex {
                                        Image(systemName: "checkmark")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button("Add Category", systemImage: "plus", action: createCategory)
                    .buttonStyle(.borderedProminent)
                    .tint(createColor)
                    .disabled(trimmedCategoryName.isEmpty)
            }
        }
    }

    private var trimmedCategoryName: String {
        categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var personalCategoriesStack: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Categories")
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)

            Text("Only you can edit or delete these.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)

            VStack(spacing: 10) {
                ForEach(personalCategories) { category in
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
            Text("System Categories")
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)

            Text("\(systemCategories.count) available to everyone")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)

            VStack(spacing: 10) {
                ForEach(systemCategories) { category in
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
                            .foregroundStyle(categoryColor)
                            .padding(8)
                            .background(categoryColor.opacity(0.1), in: .circle)
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
        let color = selectedColor
        categoryName = ""
        selectedIcon = FoodCategoryIcons.defaultIcon
        selectedColor = "#10B981"

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
        FoodCategory(id: "personal-breakfast", name: "Breakfast", icon: "sunrise.fill", color: "#F97316", createdBy: "user-1", createdAt: "2026-05-18T08:00:00Z", foodCount: 3),
        FoodCategory(id: "personal-home", name: "Home Cooking", icon: "house.fill", color: "#10B981", createdBy: "user-1", createdAt: "2026-05-18T08:00:00Z", foodCount: 4),
        FoodCategory(id: "personal-dinner", name: "Dinner", icon: "moon.fill", color: "#6366F1", createdBy: "user-1", createdAt: "2026-05-18T09:00:00Z", foodCount: 2),
        FoodCategory(id: "personal-drinks", name: "Drinks", icon: "cup.and.saucer.fill", color: "#EC4899", createdBy: "user-1", createdAt: "2026-05-18T10:00:00Z", foodCount: 2)
    ]

    return CategoryManagerView(viewModel: viewModel)
}
