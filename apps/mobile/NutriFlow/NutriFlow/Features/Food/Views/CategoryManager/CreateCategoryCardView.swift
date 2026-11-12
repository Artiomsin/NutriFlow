import SwiftUI

/// "Create a Category" card with its own name / icon / color state.
struct CreateCategoryCardView: View {
    @State private var categoryName = ""
    @State private var selectedIcon = FoodCategoryIcons.defaultIcon
    @State private var selectedColor: Color = Color(hex: "#10B981") ?? AppColors.accent

    /// Callback with (name, icon, color) when the user taps "Add Category".
    let onCreate: (String, String, String) -> Void

    var body: some View {
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

    private func createCategory() {
        let name = trimmedCategoryName
        guard !name.isEmpty else { return }

        let icon = selectedIcon
        let color = selectedColor.toHex() ?? "#10B981"
        categoryName = ""
        selectedIcon = FoodCategoryIcons.defaultIcon
        selectedColor = Color(hex: "#10B981") ?? AppColors.accent

        onCreate(name, icon, color)
    }
}
