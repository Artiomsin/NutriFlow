//
//  DailySummaryModels.swift
//  Nutriflow
//
//  Created by Artem on 20.05.26.
//

import Foundation

struct DailySummary: Codable, Identifiable {

    let id: String?
    let userId: String?

    let date: String

    let totalCalories: Int
    let totalProtein: Double
    let totalFat: Double
    let totalCarbs: Double
    let totalWaterMl: Int

    let createdAt: String?
    let updatedAt: String?
}

enum PeriodType: String, CaseIterable {
    case today
    case week
    case month
    case custom
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        case .custom: return "Custom"
        }
    }
}
struct DashboardTodayResponse: Codable {
    let dailySummary: DailySummary
    let foodEntries: [FoodEntry]
    let waterEntries: [WaterEntry]
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let label: String
    let calories: Int
    let protein: Double
    let fat: Double
    let carbs: Double
    let waterMl: Int
}


enum AggregationLevel {
    case day
    case week
    case month
}
