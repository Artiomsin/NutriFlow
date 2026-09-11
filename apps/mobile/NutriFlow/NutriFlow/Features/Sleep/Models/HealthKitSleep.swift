//
//  HealthKitSleep.swift
//  Nutriflow
//
//  Created by Artem on 09.09.2026.
//

import Foundation


enum SleepStage: Sendable, Hashable, Codable {
    case inBed
    case awake
    case core
    case deep
    case rem
    case unspecified
}

struct SleepStageSegment: Sendable, Hashable, Codable, Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let stage: SleepStage
}

struct HealthKitSleep: Sendable, Hashable, Codable, Identifiable {
    var id: UUID

    let startDate: Date
    let endDate: Date

    let timeInBedSeconds: TimeInterval
    let asleepSeconds: TimeInterval
    let awakeSeconds: TimeInterval
    let coreSeconds: TimeInterval
    let deepSeconds: TimeInterval
    let remSeconds: TimeInterval

    let unspecifiedSeconds: TimeInterval
    let awakenings: Int
    let segmentCount: Int
    let onsetLatencySeconds: TimeInterval?
    let efficiency: Double?

    var heartRateAvg: Double?
    
    let segments: [SleepStageSegment]

}

struct SleepHeartRatePoint: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let bpm: Double

    init(
        id: UUID = UUID(),
        date: Date,
        bpm: Double
    ) {
        self.id = id
        self.date = date
        self.bpm = bpm
    }
}

