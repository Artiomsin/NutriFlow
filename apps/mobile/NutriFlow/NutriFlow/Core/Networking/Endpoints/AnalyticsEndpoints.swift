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

    static func getCustomRange(from: String, to: String) -> String {
        var components = URLComponents(string: "/analytics/custom")!
        components.queryItems = [
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to)
        ]
        return components.url?.absoluteString ?? "/analytics/custom"
    }
}
