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
    static let resetToAutomatic = "/goals/reset-to-automatic"
    static let personalize = "/goals/personalize"
    static let personalizationState = "/goals/personalization"
    static let preview = "/goals/preview"
    static let applySuggestion = "/goals/apply-suggestion"
    static let dismissSuggestion = "/goals/dismiss-suggestion"
    static let clearManualOverrides = "/goals/clear-manual-overrides"
    static let clearManualOverride = "/goals/clear-manual-override"
    static let newCycle = "/goals/new-cycle"
    static let progress = "/goals/progress"
    static let applyProgressAdjustment = "/goals/progress/apply"

    static func progressRequest(days: Int) -> (path: String, query: [URLQueryItem]) {
        (
            path: progress,
            query: [URLQueryItem(name: "days", value: String(days))]
        )
    }

    static func goalHistory(
        date: String? = nil,
        limit: Int? = nil,
        cursor: String? = nil
    ) -> (path: String, query: [URLQueryItem]) {
        var query: [URLQueryItem] = []
        if let date {
            query.append(URLQueryItem(name: "date", value: date))
            // Versions are resolved by calendar day in the profile zone.
            query.append(
                URLQueryItem(
                    name: "tz",
                    value: PreferencesStore.shared.timeZone
                )
            )
        }
        if let limit {
            query.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return (path: "/goals/history", query: query)
    }

    static func acceptRecommendation(id: String) -> String {
        "/goals/personalization/\(EndpointPath.component(id))/accept"
    }

    static func dismissRecommendation(id: String) -> String {
        "/goals/personalization/\(EndpointPath.component(id))/dismiss"
    }
}
