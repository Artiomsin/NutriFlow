import SwiftUI

struct AnalyticsHeroView: View {
    let streak: Int
    let trend: TrendType

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(streak)-day streak")
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Keep going!")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textTertiary)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: trendIcon)
                    .font(.caption)
                    .foregroundColor(trendColor)
                Text(trendLabel)
                    .font(.subheadline.bold())
                    .foregroundColor(trendColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(trendColor.opacity(0.12))
            .cornerRadius(20)
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private var trendIcon: String {
        switch trend {
        case .increasing: "arrow.up.right"
        case .decreasing: "arrow.down.right"
        case .stable: "arrow.right"
        case .insufficientData: "questionmark"
        }
    }

    private var trendColor: Color {
        switch trend {
        case .increasing: .green
        case .decreasing: .orange
        case .stable: .blue
        case .insufficientData: .gray
        }
    }

    private var trendLabel: String {
        switch trend {
        case .increasing: "Increasing"
        case .decreasing: "Decreasing"
        case .stable: "Stable"
        case .insufficientData: "N/A"
        }
    }
}
