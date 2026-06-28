import SwiftUI

struct FoodCard: View {

    let entry: FoodEntry
    var onDelete: (() -> Void)?

    @State private var showDeleteAlert = false

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 8) {
                Text("\(entry.calories)")
                    .font(.title3.weight(.bold))
                    .foregroundColor(AppTheme.accent)
                Text("kcal")
                    .font(.caption2)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(width: 56, height: 56)
            .background(AppTheme.background)
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
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

                HStack(spacing: 8) {
                    MacroBadge(title: "P", value: entry.protein ?? 0)
                    MacroBadge(title: "F", value: entry.fat ?? 0)
                    MacroBadge(title: "C", value: entry.carbs ?? 0)
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
        .onLongPressGesture(minimumDuration: 0.5) {
            showDeleteAlert = true
        }
        .alert("Delete Food", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Are you sure you want to delete \"\(entry.name)\"?")
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

struct MacroBadge: View {

    let title: String
    let value: Int

    var body: some View {

        HStack(spacing: 4) {

            Text(title)
                .font(.caption.bold())
                .foregroundColor(AppTheme.accent)

            Text("\(value)g")
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.background)
        .cornerRadius(8)
    }
}