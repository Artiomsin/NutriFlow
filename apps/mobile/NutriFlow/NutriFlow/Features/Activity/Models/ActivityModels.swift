//
//  ActivityModels.swift
//  Nutriflow
//
//  Created by Artem on 03.09.2026.
//

import Foundation

struct DailyActivity: Codable, Sendable {
    let date: String
    let steps: Int
    let activeCalories: Double
    let basalCalories: Double
    let distanceMeters: Double
}

struct ActivitySyncRequest: Codable, Sendable{
    let entries: [DailyActivity]
    
}

struct ActivityDayPoint: Codable, Identifiable, Sendable {
    let date: String
    let steps: Int
    let activeCalories: Double
    let basalCalories: Double
    let distanceMeters: Double
    let caloriesConsumed: Double
    let netCalories: Double

    var id: String { date }
}


