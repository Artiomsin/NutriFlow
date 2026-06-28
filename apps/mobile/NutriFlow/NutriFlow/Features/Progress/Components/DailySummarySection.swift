import SwiftUI

struct DailySummarySection: View {

    let state: DailySummaryState
    let goals: UserGoals?

    var body: some View {

        VStack(alignment: .leading, spacing: 20) {

            header

            content
        }
    }

    private var header: some View {
        HStack {
            Text("Today's Overview")
                .font(Font.h3)
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
        }
    }

    @ViewBuilder
    private var content: some View {

        switch state {

        case .idle, .loading:
            ProgressView()

        case .loaded(let summary):
            DailySummaryCard(summary: summary, goals: goals)

        case .empty:
            if let goals = goals {
                DailySummaryCard(
                    summary: DailySummary(
                        id: "", userId: "",
                        date: "",
                        totalCalories: 0,
                        totalProtein: 0,
                        totalFat: 0,
                        totalCarbs: 0,
                        totalWaterMl: 0,
                        createdAt: nil, updatedAt: nil
                    ),
                    goals: goals
                )
            } else {
                emptyState
            }

        case .error(let error):
            ErrorMessageView(text: error.localizedDescription)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(Font.largeNumber)
                .foregroundColor(AppTheme.textSecondary)
            Text("No data for this period")
                .font(.headline)
                .foregroundColor(AppTheme.textSecondary)
            Text("Start tracking to see statistics")
                .font(.subheadline)
                .foregroundColor(AppTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DailySummarySectionPreview()
}

struct DailySummarySectionPreview: View {
    var body: some View {
        DailySummarySection(
            state: .loaded(DailySummary(
                id: "1",
                userId: "1",
                date: "2026-05-18",
                totalCalories: 1250,
                totalProtein: 85,
                totalFat: 42,
                totalCarbs: 120,
                totalWaterMl: 1750,
                createdAt: "2026-05-18T10:00:00Z",
                updatedAt: nil
            )),
            goals: nil
        )
        .padding()
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
    }
}
