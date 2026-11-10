import SwiftUI

struct CategoryIconPicker: View {
    @Binding var selection: String

    let icons: [String]
    let color: Color

    @State private var isExpanded = false

    private let columns = [
        GridItem(.adaptive(minimum: 56, maximum: 72), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: selection)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 48, height: 48)
                    .background(color.opacity(0.12), in: .circle)
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

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(color)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                toggleExpansion()
            }
            .accessibilityLabel(isExpanded ? "Hide category icons" : "Choose category icon")
            .accessibilityAddTraits(.isButton)

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
                    isSelected ? color : color.opacity(0.7)
                )
                .background(
                    isSelected ? color.opacity(0.18) : AppColors.surface,
                    in: .rect(cornerRadius: AppRadius.small)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.small)
                        .stroke(
                            isSelected ? color : color.opacity(0.16),
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
    }
}
