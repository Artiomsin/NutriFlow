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
                Image(systemName: "trash.fill")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.error)
                    .padding(8)
                    .background(AppTheme.error.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
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
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
        ]
        for fmt in formats {
            let df = DateFormatter()
            df.dateFormat = fmt
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = df.date(from: value) {
                let out = DateFormatter()
                out.dateFormat = "HH:mm"
                out.timeZone = TimeZone.current
                return out.string(from: date)
            }
        }
        return String(value.dropFirst(11).prefix(5))
    }
}
