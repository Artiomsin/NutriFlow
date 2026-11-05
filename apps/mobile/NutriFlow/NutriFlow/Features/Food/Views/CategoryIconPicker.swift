import SwiftUI

struct CategoryIconPicker: View {
    @Binding var selection: String

    let icons: [String]

    @State private var isExpanded = false

    private let columns = [
        GridItem(.adaptive(minimum: 56, maximum: 72), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: selection)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 48, height: 48)
                    .background(AppColors.accent.opacity(0.12), in: .circle)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Category icon")
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Choose an icon that makes this category easy to spot.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer(minLength: 8)

                Button(
                    isExpanded ? "Hide" : "Choose icon",
                    systemImage: isExpanded ? "chevron.up" : "chevron.down",
                    action: toggleExpansion
                )
                .labelStyle(.iconOnly)
                .foregroundStyle(AppColors.accent)
                .frame(width: 44, height: 44)
                .accessibilityLabel(isExpanded ? "Hide icons" : "Choose category icon")
            }

            if isExpanded {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(icons, id: \.self) { icon in
                        iconButton(icon)
                    }
                }
            }
        }
        .padding(14)
        .background(AppColors.surfaceSecondary, in: .rect(cornerRadius: AppRadius.medium))
        .accessibilityElement(children: .contain)
    }

    private func iconButton(_ icon: String) -> some View {
        let isSelected = selection == icon

        return Button {
            select(icon)
        } label: {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(
                    isSelected ? AppColors.accent : AppColors.accent.opacity(0.7)
                )
                .background(
                    isSelected ? AppColors.accent.opacity(0.18) : AppColors.surface,
                    in: .rect(cornerRadius: AppRadius.small)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.small)
                        .stroke(
                            isSelected ? AppColors.accent : AppColors.accent.opacity(0.16),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon.replacingOccurrences(of: ".", with: " "))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func toggleExpansion() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded.toggle()
        }
    }

    private func select(_ icon: String) {
        selection = icon
        withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded = false
        }
    }
}
