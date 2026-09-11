//
//  DailySummaryEndpoints.swift
//  Nutriflow
//
//  Created by Artem on 20.05.26.
//

import Foundation

enum DailySummaryEndpoints {
    static let getDailySummary = "/daily-summary"

    static func getDailySummaryToday(date: String?) -> (path: String, query: [URLQueryItem]) {
        (path: "/daily-summary/today", query: date.map { [URLQueryItem(name: "date", value: $0)] } ?? [])
    }

    static func getDashboardToday(date: String?) -> (path: String, query: [URLQueryItem]) {
        (path: "/daily-summary/dashboard", query: date.map { [URLQueryItem(name: "date", value: $0)] } ?? [])
    }

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
