//
//  ActivityModels.swift
//  Nutriflow
//
//  Created by Artem on 03.09.2026.
//

import Foundation

struct DailyActivity: Codable, Equatable, Sendable {
    /// A field is `nil` when its HealthKit query failed. Such fields are
    /// omitted from the JSON payload; the UI shows only the metrics that
    /// were actually read.
    let date: String
    let steps: Int?
    let activeCalories: Double?
    let basalCalories: Double?
    let distanceMeters: Double?

    var isComplete: Bool {
        steps != nil
            && activeCalories != nil
            && basalCalories != nil
            && distanceMeters != nil
    }

    var hasDisplayableMetric: Bool {
        steps != nil || activeCalories != nil || distanceMeters != nil
    }
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


