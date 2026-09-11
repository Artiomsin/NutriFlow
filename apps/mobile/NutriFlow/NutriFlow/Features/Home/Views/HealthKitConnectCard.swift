import SwiftUI

struct HealthKitConnectCard: View {
    let isConnecting: Bool
    let onConnect: () async -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                FeatureIcon(symbol: "figure.walk", color: .green)
                FeatureIcon(symbol: "bed.double.fill", color: .blue)
                FeatureIcon(symbol: "dumbbell.fill", color: .orange)
            }
            .padding(.top, 4)

            Text("Подключи HealthKit")
                .font(.title3.bold())
                .foregroundColor(AppTheme.textPrimary)

            Text("Активность, сон и тренировки появятся здесь после подключения.")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button {
                Task { await onConnect() }
            } label: {
                HStack(spacing: 10) {
                    if isConnecting {
                        ProgressView()
                            .tint(AppTheme.textPrimary)
                    } else {
                        Image(systemName: "heart.text.square.fill")
                        Text("Connect HealthKit")
                            .font(.subheadline.bold())
                    }
                }
                .foregroundColor(AppTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .disabled(isConnecting)
            .padding(.horizontal, 24)
            .padding(.bottom, 6)
        }
        .padding(.top, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
}

private struct FeatureIcon: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 20))
            .foregroundColor(color)
            .frame(width: 46, height: 46)
            .background(color.opacity(0.12))
            .clipShape(Circle())
    }
}

#Preview {
    HealthKitConnectCard(isConnecting: false, onConnect: {})
        .padding()
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
}