//
//  StatisticsView.swift
//  Nutriflow
//
//  Created by Artem on 20.05.26.
//

import SwiftUI

struct StatisticsView: View {
    @Bindable var viewModel: DailySummaryViewModel
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header
                    PeriodSelectorView(
                        selectedPeriod: viewModel.periodType,
                        fromDate: viewModel.fromDate,
                        toDate: viewModel.toDate,
                        onPeriodChange: { viewModel.setPeriod($0) },
                        onCustomRange: { from, to in viewModel.setCustomRange(from: from, to: to) }
                    )
                    chartContent
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, AppTheme.paddingHorizontal)
            }
        }
        .task { await viewModel.loadChartData() }
    }
    
    private var header: some View {
        VStack(spacing: 6) {
            Text("Statistics")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.top, AppTheme.headerPaddingTop)
            Text("Your nutrition trends")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
        }
    }
    
    @ViewBuilder
    private var chartContent: some View {
        switch viewModel.chartState {
        case .idle, .loading:
            ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.vertical, 40)
        case .loaded(let data):
            if data.isEmpty {
                emptyState
            } else {
                VStack(spacing: 20) {
                    summaryCards
                    CaloriesChartView(data: data)
                    WaterChartView(data: data)
                    NutritionChartView(data: data)
                }
            }
        case .error(let error):
            ErrorMessageView(text: error.localizedDescription)
        }
    }
    
    private var summaryCards: some View {
        HStack(spacing: 12) {
            SummaryStatCard(title: "Avg Calories", value: "\(avgCalories)", unit: "kcal/day", icon: "flame.fill", color: .orange)
            SummaryStatCard(title: "Avg Water", value: "\(avgWater)", unit: "ml/day", icon: "drop.fill", color: .blue)
        }
    }
    
    private var avgCalories: Int {
        viewModel.daysCount > 0 ? viewModel.totalCaloriesSum / viewModel.daysCount : 0
    }
    
    private var avgWater: Int {
        viewModel.daysCount > 0 ? viewModel.totalWaterSum / viewModel.daysCount : 0
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis").font(.system(size: 50)).foregroundColor(AppTheme.textSecondary)
            Text("No data for this period").font(.headline).foregroundColor(AppTheme.textSecondary)
            Text("Start tracking to see statistics").font(.subheadline).foregroundColor(AppTheme.textTertiary).multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}
struct SummaryStatCard: View {
    let title: String; let value: String; let unit: String; let icon: String; let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundColor(color)
                Text(title).font(.caption).foregroundColor(AppTheme.textSecondary)
            }
            Text(value).font(.title2.bold()).foregroundColor(AppTheme.textPrimary)
            Text(unit).font(.caption2).foregroundColor(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
}


#Preview {
    StatisticsPreviewContent()
}

struct StatisticsPreviewContent: View {
    var body: some View {
        let mockTokenStorage = MockTokenStorage(accessToken: "preview_token")
        let session = SessionManager(tokenStorage: mockTokenStorage)
        let vm = DailySummaryViewModel(
            session: session,
            service: MockDailySummaryService()
        )

        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 1
        let fromDate = calendar.date(from: components) ?? Date()
        components.month = 5
        components.day = 18
        let toDate = calendar.date(from: components) ?? Date()

        vm.periodType = .custom
        vm.fromDate = fromDate
        vm.toDate = toDate

        return StatisticsView(viewModel: vm)
            .background(AppTheme.background)
    }
}
