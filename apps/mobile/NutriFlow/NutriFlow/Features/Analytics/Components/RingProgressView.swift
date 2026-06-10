import SwiftUI

struct RingProgressView: View {
    let pct: Int
    let color: Color
    let icon: String
    let title: String
    let value: String
    let unit: String

    private var progress: Double {
        Double(min(max(pct, 0), 100)) / 100.0
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: SwiftUI.StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: progress)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }
            .frame(width: 56, height: 56)
            .shadow(color: color.opacity(0.3), radius: 4)

            Text("\(pct)%")
                .font(.caption.bold())
                .foregroundColor(color)

            Text(title)
                .font(.caption2)
                .foregroundColor(AppTheme.textSecondary)

            HStack(spacing: 2) {
                Text(value)
                    .font(.caption2.bold())
                    .foregroundColor(AppTheme.textPrimary)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(AppTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
}
