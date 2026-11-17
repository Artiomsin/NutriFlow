import SwiftUI

/// A snapshot of today's current weight. Trend data belongs to period cards;
/// showing a one-point chart here would suggest a change that does not exist.
struct TodayWeightCardView: View {
    let latestKg: Double?
    let isLoading: Bool
    let error: AppError?
    let onRetry: () -> Void
    let onRecordWeight: () -> Void
    let onManageWeights: () -> Void

    @State private var preferencesStore = PreferencesStore.shared

    private var unit: String {
        UnitConversion.bodyWeightUnitLabel(preferred: preferencesStore.preferredUnits)
    }

    private var weightText: String {
        guard let latestKg else { return "—" }
        return UnitConversion.formatBodyWeight(kg: latestKg, preferred: preferencesStore.preferredUnits)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let error, latestKg == nil {
                ErrorView(error: error, onRetry: onRetry)
            } else if latestKg != nil {
                snapshot
                    .opacity(isLoading ? 0.55 : 1)
            } else if isLoading {
                loadingPlaceholder
            } else {
                emptyState
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: WeightCardLayout.stableMinimumHeight, alignment: .topLeading)
        .appGlassSurface()
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "scalemass.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 32, height: 32)
                .background(AppColors.accent.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Weight")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                HStack(spacing: 5) {
                    Text("Today")
                    if isLoading {
                        SkeletonBlock(width: 28, height: 9, cornerRadius: 4.5)
                            .skeletonShimmer()
                            .accessibilityLabel("Updating weight")
                    }
                }
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            if error != nil, latestKg != nil {
                Button(action: onRetry) {
                    Label("Retry loading weight", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                        .font(.footnote.weight(.semibold))
                        .frame(width: 32, height: 32)
                }
                .foregroundStyle(AppColors.warning)
            }

            Button(action: onManageWeights) {
                Label("Manage weight records", systemImage: "clock.arrow.circlepath")
                    .labelStyle(.iconOnly)
                    .font(.footnote.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .foregroundStyle(AppColors.textSecondary)

            Button(action: onRecordWeight) {
                Label("Record", systemImage: "plus")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 32)
            }
            .foregroundStyle(AppColors.accentOnPrimary)
            .background(AppColors.accent)
            .clipShape(Capsule())
        }
    }

    private var snapshot: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CURRENT WEIGHT")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.textTertiary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(weightText)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppColors.textPrimary)
                    Text(unit)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(AppColors.success)
                .accessibilityLabel("Current weight recorded")
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
    }

    private var loadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonBlock(width: 92, height: 12)
            SkeletonBlock(width: 150, height: 34)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .skeletonShimmer()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No current weight")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
            Button("Record weight", systemImage: "plus", action: onRecordWeight)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColors.accent)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
    }
}
