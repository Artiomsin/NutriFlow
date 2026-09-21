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
                .foregroundColor(AppColors.textPrimary)

            Text("Активность, сон и тренировки появятся здесь после подключения.")
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button {
                Task { await onConnect() }
            } label: {
                HStack(spacing: 10) {
                    if isConnecting {
                        ProgressView()
                    } else {
                        Image(systemName: "heart.text.square.fill")

                        Text("Connect HealthKit")
                            .font(.subheadline.bold())
                    }
                }
                .foregroundStyle(AppColors.accentOnPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            }
            .disabled(isConnecting)
            .padding(.horizontal, 24)
            .padding(.bottom, 6)
        }
        .padding(.top, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.medium)
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
        .background(AppColors.background)
       // .preferredColorScheme(.dark)
}
