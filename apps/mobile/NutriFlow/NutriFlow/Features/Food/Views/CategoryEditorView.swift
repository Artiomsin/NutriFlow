import SwiftUI

struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let category: FoodCategory

    @Bindable var viewModel: AddFoodViewModel

    @State private var name: String
    @State private var icon: String
    @State private var color: String

    private let presetColors: [String] = [
        "#10B981", "#EF4444", "#3B82F6", "#F59E0B",
        "#EC4899", "#84CC16", "#A855F7", "#06B6D4",
        "#F97316", "#6366F1", "#14B8A6", "#8B5CF6",
    ]

    init(
        category: FoodCategory,
        viewModel: AddFoodViewModel
    ) {
        self.category = category
        self.viewModel = viewModel

        _name = State(initialValue: category.name)
        _icon = State(initialValue: category.icon ?? FoodCategoryIcons.defaultIcon)
        _color = State(initialValue: category.color ?? "#10B981")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedColor: Color {
        Color(hex: color) ?? Color(hex: "#10B981") ?? AppColors.accent
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
                        icons: FoodCategoryIcons.all
                    )

                    // Color picker (preset colors, simple grid)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal, 4)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                            ForEach(presetColors, id: \.self) { hex in
                                Button {
                                    color = hex
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: hex) ?? AppColors.accent)
                                            .frame(width: 36, height: 36)

                                        if color == hex {
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
                color: color
            ) {
                dismiss()
            }
        }
    }
}

// MARK: - Color hex extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }
        let r, g, b, a: Double
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b, a) = (
                Double((int >> 16) & 0xFF) / 255,
                Double((int >> 8) & 0xFF) / 255,
                Double(int & 0xFF) / 255,
                1.0
            )
        case 8: // ARGB (32-bit)
            (r, g, b, a) = (
                Double((int >> 16) & 0xFF) / 255,
                Double((int >> 8) & 0xFF) / 255,
                Double(int & 0xFF) / 255,
                Double((int >> 24) & 0xFF) / 255
            )
        default:
            return nil
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    func toHex() -> String? {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return String(format: "%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}
