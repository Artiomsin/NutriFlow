//
//  DailySummarySection.swift
//  Nutriflow
//

import SwiftUI

struct DailySummarySection: View {

    @Bindable var viewModel: DailySummaryViewModel

    var body: some View {

        VStack(alignment: .leading, spacing: 20) {

            header

            content
        }
    }

    private var header: some View {
        HStack {
            Text("Today's Overview")
                .font(.title3.bold())
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
        }
    }

    @ViewBuilder
    private var content: some View {

        switch viewModel.state {

        case .idle, .loading:
            ProgressView()

        case .loaded(let summary):
            DailySummaryCard(summary: summary)

        case .empty:
            emptyState

        case .error(let error):
            ErrorMessageView(text: error.localizedDescription)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 50))
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
        let session = SessionManager(tokenStorage: TokenStorage(keychain: KeychainService()))

        let dailyVM = DailySummaryViewModel(
            session: session,
            service: MockDailySummaryService()
        )
        dailyVM.setPreviewState(.loaded(DailySummary(
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
        )))

        return DailySummarySection(viewModel: dailyVM)
            .padding()
            .background(AppTheme.background)
            .preferredColorScheme(.dark)
    }
}
