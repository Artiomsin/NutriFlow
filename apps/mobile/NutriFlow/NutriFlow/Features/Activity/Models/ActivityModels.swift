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
    let activeCalories: Int
    let basalCalories: Int
    let distanceMeters: Double
}

struct ActivitySyncRequest: Codable, Sendable{
    let entries: [DailyActivity]
    
}

struct ActivityDayPoint: Codable, Identifiable, Sendable {
    let date: String
    let steps: Int
    let activeCalories: Int
    let basalCalories: Int
    let distanceMeters: Double
    let caloriesConsumed: Int
    let netCalories: Int

    var id: String { date }
}



