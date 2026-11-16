import SwiftUI

struct WaterCard: View {

    let entry: WaterEntry
    var onDelete: (() -> Void)?

    @State private var showDeleteAlert = false
    @State private var prefsStore = PreferencesStore.shared

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "drop.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(UnitConversion.formatAmount(grams: entry.amountMl, unit: "ml", preferred: prefsStore.preferredUnits))
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                    Text(formatTime(entry.createdAt))
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            Button {
                showDeleteAlert = true
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.error)
                    .padding(8)
                    .background(AppColors.error.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlassSurface(level: .interactive)
        .contentShape(Rectangle())
        .alert("Delete Water", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Are you sure you want to delete this water entry?")
        }
    }

    private func formatTime(_ value: String) -> String {
        AppDate.formatTime(value)
    }
}
