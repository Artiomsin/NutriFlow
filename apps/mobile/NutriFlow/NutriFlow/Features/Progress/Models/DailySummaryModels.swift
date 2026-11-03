//
//  DailySummaryModels.swift
//  Nutriflow
//
//  Created by Artem on 20.05.26.
//

import Foundation

struct DailySummary: Codable, Identifiable, Sendable {

    let id: String?
    let userId: String?

    let date: String

    let totalCalories: Double
    let totalProtein: Double
    let totalFat: Double
    let totalCarbs: Double
    let totalWaterMl: Int

    let createdAt: String?
    let updatedAt: String?
}

enum PeriodType: String, CaseIterable, Sendable {
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
struct DashboardTodayResponse: Codable, Sendable {
    let dailySummary: DailySummary
    let foodEntries: [FoodEntry]
    let waterEntries: [WaterEntry]
}

struct ChartDataPoint: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let label: String
    let calories: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let waterMl: Int
    var steps: Int = 0
    var activeCalories: Int = 0
    var basalCalories: Int = 0
    var distanceMeters: Double = 0
    var netCalories: Int = 0
}


enum AggregationLevel: Sendable {
    case day
    case week
    case month
}
