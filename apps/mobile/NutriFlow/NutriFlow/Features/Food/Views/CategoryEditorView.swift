import SwiftUI

struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let category: FoodCategory
    @Bindable var viewModel: AddFoodViewModel

    @State private var name: String
    @State private var icon: String

    init(category: FoodCategory, viewModel: AddFoodViewModel) {
        self.category = category
        self.viewModel = viewModel
        _name = State(initialValue: category.name)
        _icon = State(initialValue: category.icon ?? "tag.fill")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    TextField("Name", text: $name)
                    CategoryIconPicker(selection: $icon)
                }
            }
            .navigationTitle("Edit Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        Task {
            if await viewModel.updateCategory(category, name: name, icon: icon) {
                dismiss()
            }
        }
    }
}
