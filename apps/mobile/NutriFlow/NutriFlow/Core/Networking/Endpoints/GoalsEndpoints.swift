//
//  GoalsEndpoints.swift
//  Nutriflow
//
//  Created by Artem on 4.06.26.
//

import Foundation

enum GoalsEndpoints {

    static let getGoals = "/goals"
    static let updateGoals = "/goals"
    static let calculateGoals = "/goals/calculate"
    static let personalize = "/goal/personalize"
    static let personalizationState = "/goals/personalization"
    static let goalHistory = "/goals/history"

    static func acceptRecommendation(id: String) -> String {
        "/goals/personalization/\(id)/accept"
    }

    static func dismissRecommendation(id: String) -> String {
        "/goals/personalization/\(id)/dismiss"
    }
}
