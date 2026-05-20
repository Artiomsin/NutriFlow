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
