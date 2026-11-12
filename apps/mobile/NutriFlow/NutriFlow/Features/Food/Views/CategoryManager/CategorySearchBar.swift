import SwiftUI

/// Search field with All / Personal / System scope toggle buttons.
struct CategorySearchBar: View {
    @Binding var searchText: String
    @Binding var scope: SearchScope

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Search categories", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .frame(height: 48)
                .padding(.horizontal, 12)
                .background(AppColors.surfaceSecondary)
                .clipShape(.rect(cornerRadius: AppRadius.medium))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(AppColors.border, lineWidth: 1)
                }

            SearchScopePicker(selection: $scope)
        }
    }
}

/// Green accent toggle buttons for All / Personal / System filtering.
private struct SearchScopePicker: View {
    @Binding var selection: SearchScope

    var body: some View {
        HStack(spacing: 8) {
            ForEach(SearchScope.allCases, id: \.self) { scope in
                Button {
                    selection = scope
                } label: {
                    Text(scope.displayTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selection == scope ? .white : AppColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selection == scope
                                ? AppColors.accent
                                : AppColors.surfaceSecondary,
                            in: .rect(cornerRadius: AppRadius.medium)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .stroke(
                                    selection == scope ? Color.clear : AppColors.accent.opacity(0.4),
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Scope: \(scope.displayTitle)"))
                .accessibilityAddTraits(selection == scope ? .isSelected : [])
            }
        }
    }
}
