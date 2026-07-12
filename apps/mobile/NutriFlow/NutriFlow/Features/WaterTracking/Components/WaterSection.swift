import SwiftUI

struct WaterSection: View {

    @Bindable var waterViewModel: WaterViewModel
    var onAddWater: (() -> Void)?
    var onDeleteWater: ((String) -> Void)?

    var body: some View {

        VStack(alignment: .leading, spacing: 20) {

            HStack {

                Text("Water")
                    .font(Font.h3)
                    .foregroundColor(AppTheme.textPrimary)

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
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(AppTheme.accent)
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

            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity)

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

            ProgressView()
                .tint(.white)

        case .error(let error):

            ErrorMessageView(text: error.localizedDescription)
        }
    }

    private func sortedEntries(_ entries: [WaterEntry]) -> [WaterEntry] {
        entries.sorted { $0.createdAt > $1.createdAt }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "drop.circle")
                .font(.system(size: 42))
                .foregroundColor(AppTheme.textSecondary)

            Text("No water added today")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
}

#Preview {
    WaterSectionPreview()
}

struct WaterSectionPreview: View {
    var body: some View {
        let waterVM = WaterViewModel(
            coordinator: AppCoordinator(container: AppDependencyContainer()),
            service: MockWaterService()
        )
        waterVM.setPreviewState(.loaded([
            WaterEntry(id: "1", userId: "1", amountMl: 250, createdAt: "2026-05-18T08:00:00Z", updatedAt: nil),
            WaterEntry(id: "2", userId: "1", amountMl: 500, createdAt: "2026-05-18T10:30:00Z", updatedAt: nil),
            WaterEntry(id: "3", userId: "1", amountMl: 750, createdAt: "2026-05-18T12:00:00Z", updatedAt: nil)
        ]))

        return WaterSection(
            waterViewModel: waterVM,
            onAddWater: {},
            onDeleteWater: { _ in }
        )
        .padding()
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
    }
}