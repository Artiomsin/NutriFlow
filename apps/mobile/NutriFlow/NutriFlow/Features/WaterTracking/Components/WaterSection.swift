import SwiftUI

struct WaterSection: View {

    @Bindable var waterViewModel: WaterViewModel
    var onAddWater: (() -> Void)?
    var onDeleteWater: ((String) -> Void)?

    var body: some View {

        VStack(alignment: .leading, spacing: 20) {

            HStack {

                Text("Water")
                    .font(.title3.weight(.bold))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Button {
                    onAddWater?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Add")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(AppColors.accentOnPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(AppColors.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch waterViewModel.state {
        case .idle, .loading:
            waterSkeleton

        case .loaded(let entries):
            if entries.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(sortedEntries(entries)) { entry in
                        WaterCard(entry: entry) {
                            onDeleteWater?(entry.id)
                        }
                    }
                }
            }

        case .saving:
            EmptyView()

        case .error(let error):
            ErrorView(error: error) {
                Task {
                    await waterViewModel.loadToday()
                }
            }
        }
    }

    private var waterSkeleton: some View {
        LazyVStack(spacing: 14) {
            waterSkeletonCard
            waterSkeletonCard
            waterSkeletonCard
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading water entries")
    }

    private var waterSkeletonCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(AppColors.textSecondary.opacity(0.12))
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(AppColors.textSecondary.opacity(0.14))
                    .frame(width: 85, height: 17)

                HStack(spacing: 6) {
                    Circle()
                        .fill(AppColors.textSecondary.opacity(0.10))
                        .frame(width: 10, height: 10)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.textSecondary.opacity(0.10))
                        .frame(width: 45, height: 12)
                }
            }

            Spacer()

            Circle()
                .fill(AppColors.textSecondary.opacity(0.10))
                .frame(width: 27, height: 27)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlassSurface(level: .interactive)
    }
    
    private func sortedEntries(_ entries: [WaterEntry]) -> [WaterEntry] {
        entries.sorted { $0.createdAt > $1.createdAt }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "drop.circle")
                .font(.system(size: 42))
                .foregroundColor(AppColors.textSecondary)

            Text("No water added today")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .appGlassSurface()
    }
}

#Preview("Water - Loading") {
    WaterSectionPreview { vm in
        vm.setPreviewState(.loading)
    }
}
#Preview("Water - Loaded") {
    WaterSectionPreview { vm in
        vm.setPreviewState(.loaded([
            WaterEntry(id: "1", userId: "1", amountMl: 250, createdAt: "2026-05-18T08:00:00Z", updatedAt: nil),
            WaterEntry(id: "2", userId: "1", amountMl: 500, createdAt: "2026-05-18T10:30:00Z", updatedAt: nil),
            WaterEntry(id: "3", userId: "1", amountMl: 750, createdAt: "2026-05-18T12:00:00Z", updatedAt: nil)
        ]))
    }
}

#Preview("Water - Empty") {
    WaterSectionPreview { vm in
        vm.setPreviewState(.loaded([]))
    }
}

#Preview("Water - Saving") {
    WaterSectionPreview { vm in
        vm.setPreviewState(.saving)
    }
}

struct WaterSectionPreview: View {
    let configure: (WaterViewModel) -> Void

    var body: some View {
        let waterVM = WaterViewModel(
            coordinator: AppCoordinator(container: AppDependencyContainer()),
            service: MockWaterService()
        )

        configure(waterVM)

        return WaterSection(
            waterViewModel: waterVM,
            onAddWater: {},
            onDeleteWater: { _ in }
        )
        .padding()
        .background(AppColors.background)
        .preferredColorScheme(.dark)
    }
}
