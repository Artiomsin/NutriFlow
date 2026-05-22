//
//  DailySummaryEndpoints.swift
//  Nutriflow
//
//  Created by Artem on 20.05.26.
//

import Foundation

enum DailySummaryEndpoints {

    static let getDailySummaryToday = "/daily-summary/today"
    static let getDailySummary = "/daily-summary"
    static let getDailySummaryRange = "/daily-summary/range"

    static func getDailySummaryByDate(date: String) -> String {
        var components = URLComponents(string: "/daily-summary")!
        components.queryItems = [URLQueryItem(name: "date", value: date)]
        return components.url?.absoluteString ?? "/daily-summary"
    }

    static func getDailySummaryRange(from: String, to: String) -> String {
        var components = URLComponents(string: "/daily-summary/range")!
        components.queryItems = [
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to)
        ]
        return components.url?.absoluteString ?? "/daily-summary/range"
    }
}
