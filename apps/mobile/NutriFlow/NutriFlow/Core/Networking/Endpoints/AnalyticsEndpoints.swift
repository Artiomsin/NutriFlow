//
//  AnalyticsEndpoints.swift
//  Nutriflow
//
//  Created by Artem on 4.06.26.
//

import Foundation

enum AnalyticsEndpoints {

    static let getWeek = "/analytics/week"
    static let getMonth = "/analytics/month"
    static let getCustom = "/analytics/custom"

    static func getCustomRange(from: String, to: String) -> (path: String, query: [URLQueryItem]) {
        (path: "/analytics/custom", query: [
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to)
        ])
    }
}
