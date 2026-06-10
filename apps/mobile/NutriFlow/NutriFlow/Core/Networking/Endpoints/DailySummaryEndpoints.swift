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
    static let getDashboardToday = "/daily-summary/dashboard"
    static let getDailySummaryRange = "/daily-summary/range"

    static func getDailySummaryByDate(date: String) -> (path: String, query: [URLQueryItem]) {
        (path: "/daily-summary", query: [URLQueryItem(name: "date", value: date)])
    }

    static func getDailySummaryRange(from: String, to: String) -> (path: String, query: [URLQueryItem]) {
        (path: "/daily-summary/range", query: [
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to)
        ])
    }
}
