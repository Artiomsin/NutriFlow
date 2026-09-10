//
//  SleepHealthKitServiceProtocol.swift
//  Nutriflow
//
//  Created by Artem on 09.09.2026.
//

import Foundation

protocol SleepHealthKitServiceProtocol: Sendable {
    var isAvailable: Bool { get }
    
    func requestAuthorization() async throws
    
    func fetchSleep(from startDate: Date,
                    to endDate: Date) async throws->HealthKitSleep?
    
    func fetchNights(from startDate: Date,
                        to endDate: Date) async throws -> [HealthKitSleep]

    func fetchHeartRateDuringSleep(
        from start: Date,
        to end: Date
    ) async throws -> [SleepHeartRatePoint]
}

