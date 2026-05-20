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
        "/daily-summary?date=\(date)"
    }

    static func getDailySummaryRange(from: String, to: String) -> String {
        "/daily-summary/range?from=\(from)&to=\(to)"
    }
}
