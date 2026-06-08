//
//  StatisticsView.swift
//  Nutriflow
//
//  Created by Artem on 20.05.26.
//

import SwiftUI

struct ProgressDashboardView: View {
    @Bindable var viewModel: DailySummaryViewModel
    var body: some View {
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
        .onAppear { AnalyticsService.shared.track(.screenView(screen: "progress")) }
        .task { await viewModel.loadChartData() }
    }
    
    private var header: some View {
        VStack(spacing: 6) {
            Text("Progress")
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
            let hasData = data.contains { $0.calories > 0 || $0.waterMl > 0 || $0.protein > 0 || $0.fat > 0 || $0.carbs > 0 }
            if data.isEmpty || !hasData {
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


#Preview("NutriFlow Progress") {
    let vm = DailySummaryViewModel(
        coordinator: AppCoordinator(container: AppDependencyContainer()),
        service: MockDailySummaryService()
    )
    vm.periodType = .week
    return ProgressDashboardView(viewModel: vm).background(AppTheme.background)
}
