import SwiftUI

struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let category: FoodCategory

    @Bindable var viewModel: AddFoodViewModel

    @State private var name: String
    @State private var icon: String

    init(
        category: FoodCategory,
        viewModel: AddFoodViewModel
    ) {
        self.category = category
        self.viewModel = viewModel

        _name = State(initialValue: category.name)
        _icon = State(
            initialValue: category.icon ?? FoodCategoryIcons.defaultIcon
        )
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)

                    CategoryIconPicker(
                        selection: $icon,
                        icons: FoodCategoryIcons.all
                    )
                }
            }
            .navigationTitle("Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedName.isEmpty)
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
                icon: icon
            ) {
                dismiss()
            }
        }
    }
}
