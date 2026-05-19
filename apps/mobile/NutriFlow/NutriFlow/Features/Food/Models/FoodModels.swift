//
//  FoodModels.swift
//  Nutriflow
//
//  Created by Artem on 18.05.26.
//

import Foundation

struct CreateFoodRequest: Codable {
    let name: String
    let calories: Int
    let protein: Int?
    let fat: Int?
    let carbs: Int?
}

struct UpdateFoodEntryRequest: Codable {

    let name: String?

    let calories: Int?
    let protein: Int?
    let fat: Int?
    let carbs: Int?
}

struct FoodEntry: Codable, Identifiable {

    let id: String
    let userId: String

    let name: String

    let calories: Int
    let protein: Int?
    let fat: Int?
    let carbs: Int?

    let createdAt: String
    let updatedAt: String?
}
