//
//  StatisticsTabFlow.swift
//  Nutriflow
//
//  Created by Artem on 20.05.26.
//

import SwiftUI
struct StatisticsTabFlow: View {
    @Bindable var dailyViewModel: DailySummaryViewModel
    @Bindable var session: SessionManager
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            StatisticsView(viewModel: dailyViewModel)
        }
    }
}
