import SwiftUI

struct ErrorView: View {
    let error: AppError
    let onRetry: (() -> Void)?

    init(error: AppError, onRetry: (() -> Void)? = nil) {
        self.error = error
        self.onRetry = onRetry
    }

    var body: some View {
        if error == .cancelled {
            EmptyView()
        } else {
            content
        }
    }

    private var content: some View {
        let presentation = ErrorPresentation(error: error)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(AppColors.error)

                VStack(alignment: .leading, spacing: 4) {
                    Text(presentation.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(presentation.message)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if presentation.allowsRetry, let onRetry {
                Button("Try again", action: onRetry)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColors.error)
                    .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.errorBackground)
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.small)
                .stroke(AppColors.error.opacity(0.2), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
        .accessibilityElement(children: .combine)
    }
}
