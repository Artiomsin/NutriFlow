import SwiftUI

struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let category: FoodCategory

    @Bindable var viewModel: AddFoodViewModel

    @State private var name: String
    @State private var icon: String
    @State private var selectedColor: Color

    init(
        category: FoodCategory,
        viewModel: AddFoodViewModel
    ) {
        self.category = category
        self.viewModel = viewModel

        _name = State(initialValue: category.name)
        _icon = State(initialValue: category.icon ?? FoodCategoryIcons.defaultIcon)
        _selectedColor = State(initialValue: Color(hex: category.color ?? "#10B981") ?? AppColors.accent)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with current icon (centered)
                    VStack(spacing: 16) {
                        CategoryIconView(
                            iconName: icon,
                            color: selectedColor
                        )
                        .frame(width: 80, height: 80)
                        .background(selectedColor.opacity(0.15))
                        .clipShape(.circle)

                        TextField("Category name", text: $name)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .frame(maxWidth: 280)
                            .padding(.vertical, 14)
                            .background(AppColors.surfaceSecondary)
                            .clipShape(.rect(cornerRadius: AppRadius.large))

                        Text("\(category.foodCount) foods")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.top, 20)

                    // Icon picker (dropdown style)
                    CategoryIconPicker(
                        selection: $icon,
                        icons: FoodCategoryIcons.all,
                        color: selectedColor
                    )

                    // Color picker (gradient bar)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal, 4)

                        GradientColorPicker(selectedColor: $selectedColor)
                    }
                    .padding(.horizontal, 4)

                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(AppColors.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(trimmedName.isEmpty)
                    .foregroundStyle(trimmedName.isEmpty ? AppColors.textTertiary : selectedColor)
                }
            }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }

        Task {
            if await viewModel.updateCategory(
                category,
                name: trimmedName,
                icon: icon,
                color: selectedColor.toHex() ?? "#10B981"
            ) {
                dismiss()
            }
        }
    }
}
