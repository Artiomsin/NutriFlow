//
//  DailySummaryServiceProtocol.swift
//  Nutriflow
//
//  Created by Artem on 20.05.26.
//

import Foundation

protocol DailySummaryServiceProtocol {

    func getTodayDailySummary(
        token: String
    ) async throws -> DailySummary

    func getDailySummaryByDate(
        token: String,
        date: String
    ) async throws -> DailySummary

    func getDailySummaryRange(
        token: String,
        from: String,
        to: String
    ) async throws -> [DailySummary]
}
