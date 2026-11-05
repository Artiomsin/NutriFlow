import SwiftUI

struct CategoryManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AddFoodViewModel

    @State private var categoryName = ""
    @State private var selectedIcon = "tag.fill"
    @State private var categoryToDelete: FoodCategory?
    @State private var categoryToEdit: FoodCategory?
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
                VStack(spacing: 20) {
                    introductionCard
                    createCategoryCard

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
                .padding()
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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
                Button("Delete \(category.name)", role: .destructive) {
                    Task { await viewModel.deleteCategory(category) }
                }
            } message: { category in
                Text("\(category.name) can be deleted only when no products use it.")
            }
            .sheet(item: $categoryToEdit) { category in
                CategoryEditorView(category: category, viewModel: viewModel)
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
                    Text("Assign a category while adding a food. System categories are shared; yours stay private.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
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

                TextField("For example, Homemade meals", text: $categoryName)
                    .textInputAutocapitalization(.words)
                    .padding(12)
                    .background(AppColors.surfaceSecondary)
                    .clipShape(.rect(cornerRadius: AppRadius.medium))

                Text("Icon")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textPrimary)

                CategoryIconPicker(selection: $selectedIcon)

                Button("Add Category", systemImage: "plus", action: createCategory)
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.accent)
                    .disabled(categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var systemCategoriesSection: some View {
        AppCard {
            DisclosureGroup(isExpanded: $areSystemCategoriesExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(systemCategories) { category in
                        categoryRow(category, showsDeleteAction: false)
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
                        Text("\(systemCategories.count) available to everyone")
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
                        categoryRow(category, showsDeleteAction: showsDeleteAction)
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
            Image(systemName: category.icon ?? "tag.fill")
                .foregroundStyle(AppColors.accent)
                .frame(width: 28, height: 28)
                .background(AppColors.accent.opacity(0.12))
                .clipShape(.circle)

            Button(category.name) {
                if category.isPersonal { categoryToEdit = category }
            }
            .buttonStyle(.plain)
            .font(.body.weight(.medium))
            .foregroundStyle(AppColors.textPrimary)

            Spacer()

            if showsDeleteAction {
                Button("Delete", systemImage: "trash", role: .destructive) {
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
        let name = categoryName
        categoryName = ""
        let icon = selectedIcon
        selectedIcon = "tag.fill"
        Task { await viewModel.createCategory(named: name, icon: icon) }
    }
}
