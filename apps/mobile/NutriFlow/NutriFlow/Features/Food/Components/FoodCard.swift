import SwiftUI
import Kingfisher

struct FoodCard: View {

    let entry: FoodEntry
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    @State private var showDeleteAlert = false
    @State private var prefsStore = PreferencesStore.shared

    var body: some View {
        HStack(spacing: 14) {
            imageView

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    HStack(spacing: 2) {
                        Text("\(UnitConversion.formatEnergyValue(kcal: entry.calories, preferred: prefsStore.preferredUnits))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppTheme.accent)
                        Text(UnitConversion.formatEnergyUnit(preferred: prefsStore.preferredUnits))
                            .font(.system(size: 9))
                            .foregroundColor(AppTheme.accent.opacity(0.7))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.accent.opacity(0.12))
                    .clipShape(Capsule())
                }

                Text(formatTime(entry.createdAt))
                    .font(.caption)
                    .foregroundColor(AppTheme.textTertiary)

                HStack(spacing: 12) {
                    MacroDot(color: Color(red: 0.22, green: 0.6, blue: 0.99),
                              label: "P", value: UnitConversion.formatMacro(grams: entry.protein ?? 0, preferred: prefsStore.preferredUnits))
                    MacroDot(color: Color(red: 1.0, green: 0.58, blue: 0.18),
                              label: "F", value: UnitConversion.formatMacro(grams: entry.fat ?? 0, preferred: prefsStore.preferredUnits))
                    MacroDot(color: Color(red: 0.28, green: 0.82, blue: 0.38),
                              label: "C", value: UnitConversion.formatMacro(grams: entry.carbs ?? 0, preferred: prefsStore.preferredUnits))
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    onEdit?()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.accent)
                        .padding(8)
                        .background(AppTheme.accent.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

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

                if let grams = entry.grams, grams > 0 {
                    Text(UnitConversion.formatAmount(grams: grams, unit: entry.unit, preferred: prefsStore.preferredUnits))
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .alert("Delete Food", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Delete \"\(entry.name)\"?")
        }
    }

    @ViewBuilder
    private var imageView: some View {
        if let url = entry.displayImageUrl.flatMap({ URL(string: $0) }) {
            ZStack {
                fallbackIcon
                KFImage(url)
                    .resizable()
                    .scaledToFill()
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            fallbackIcon
        }
    }

    private var fallbackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.1, green: 0.15, blue: 0.25))
            Image(systemName: "fork.knife")
                .font(.system(size: 20))
                .foregroundColor(Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.5))
        }
        .frame(width: 56, height: 56)
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

struct MacroDot: View {
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}

struct MacroBadge: View {

    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(AppTheme.accent)

            Text(value)
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.background)
        .cornerRadius(8)
    }
}
