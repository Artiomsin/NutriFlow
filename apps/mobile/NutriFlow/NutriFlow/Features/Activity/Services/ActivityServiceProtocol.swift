//
//  ActivityServiceProtocol.swift
//  Nutriflow
//
//  Created by Artem on 03.09.2026.
//

import Foundation

protocol ActivityServiceProtocol {
    func sync(entries: [DailyActivity]) async throws
    func getRange(from: String, to: String)  async throws -> [ActivityDayPoint]
}
