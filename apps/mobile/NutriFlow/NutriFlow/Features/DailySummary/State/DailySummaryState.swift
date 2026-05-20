//
//  DailySummaryState.swift
//  Nutriflow
//
//  Created by Artem on 20.05.26.
//

import Foundation

enum DailySummaryState {
    case idle
    case loading
    case loaded(DailySummary)
    case error(Error)
}

enum ChartState {
    case idle
    case loading
    case loaded([ChartDataPoint])
    case error(Error)
}
