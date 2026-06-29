import SwiftUI

struct WaterCard: View {

    let entry: WaterEntry
    var onDelete: (() -> Void)?

    @State private var showDeleteAlert = false

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
                Text("\(entry.amountMl) ml")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                    Text(formatTime(entry.createdAt))
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()

            Button {
                showDeleteAlert = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.error.opacity(0.6))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.5) {
            showDeleteAlert = true
        }
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
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) ?? ISO8601DateFormatter().date(from: value) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        return String(value.dropFirst(11).prefix(5))
    }
}
