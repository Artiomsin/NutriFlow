//
//  WorkoutModels.swift
//  Nutriflow
//
//  Created by Artem on 05.09.2026.
//

import Foundation


struct WorkoutDetails: Codable, Hashable, Sendable {
    var stroke: String?
    var water: String?
    var lapLengthMeters: Double?
    var swolf: Double?
    var elevationAscended: Double?
    var elevationDescended: Double?
    var avgMETs: Double?

    init(
        stroke: String? = nil,
        water: String? = nil,
        lapLengthMeters: Double? = nil,
        swolf: Double? = nil,
        elevationAscended: Double? = nil,
        elevationDescended: Double? = nil,
        avgMETs: Double? = nil
    ) {
        self.stroke = stroke
        self.water = water
        self.lapLengthMeters = lapLengthMeters
        self.swolf = swolf
        self.elevationAscended = elevationAscended
        self.elevationDescended = elevationDescended
        self.avgMETs = avgMETs
    }

    var isEmpty: Bool {
        stroke == nil && water == nil && lapLengthMeters == nil && swolf == nil
            && elevationAscended == nil && elevationDescended == nil && avgMETs == nil
    }
}

struct HealthKitWorkout: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let workoutType: String
    let startDate: Date
    let endDate: Date
    let durationSeconds: Double
    let caloriesBurned: Double?
    let distanceMeters: Double?
    let heartRateAvg: Double?
    let heartRateMax: Double?
    let heartRateMin: Double?
    let avgSpeedMps: Double?
    let maxSpeedMps: Double?
    let avgCadence: Double?
    let maxCadence: Double?
    let avgPowerWatts: Double?
    let maxPowerWatts: Double?
    let elevationGainMeters: Double?
    let steps: Int?
    let indoor: Bool?
    let details: WorkoutDetails?

    init(
        id: UUID,
        workoutType: String,
        startDate: Date,
        endDate: Date,
        durationSeconds: Double,
        caloriesBurned: Double?,
        distanceMeters: Double?,
        heartRateAvg: Double? = nil,
        heartRateMax: Double? = nil,
        heartRateMin: Double? = nil,
        avgSpeedMps: Double? = nil,
        maxSpeedMps: Double? = nil,
        avgCadence: Double? = nil,
        maxCadence: Double? = nil,
        avgPowerWatts: Double? = nil,
        maxPowerWatts: Double? = nil,
        elevationGainMeters: Double? = nil,
        steps: Int? = nil,
        indoor: Bool? = nil,
        details: WorkoutDetails? = nil
    ) {
        self.id = id
        self.workoutType = workoutType
        self.startDate = startDate
        self.endDate = endDate
        self.durationSeconds = durationSeconds
        self.caloriesBurned = caloriesBurned
        self.distanceMeters = distanceMeters
        self.heartRateAvg = heartRateAvg
        self.heartRateMax = heartRateMax
        self.heartRateMin = heartRateMin
        self.avgSpeedMps = avgSpeedMps
        self.maxSpeedMps = maxSpeedMps
        self.avgCadence = avgCadence
        self.maxCadence = maxCadence
        self.avgPowerWatts = avgPowerWatts
        self.maxPowerWatts = maxPowerWatts
        self.elevationGainMeters = elevationGainMeters
        self.steps = steps
        self.indoor = indoor
        self.details = details
    }
}


struct WorkoutSyncEntry: Codable, Sendable {
    let healthKitWorkoutId: String
    let type: String
    let startDate: String
    let endDate: String
    let durationSeconds: Double
    let caloriesBurned: Double?
    let distanceMeters: Double?
    let heartRateAvg: Double?
    let heartRateMax: Double?
    let heartRateMin: Double?
    let avgSpeedMps: Double?
    let maxSpeedMps: Double?
    let avgCadence: Double?
    let maxCadence: Double?
    let avgPowerWatts: Double?
    let maxPowerWatts: Double?
    let elevationGainMeters: Double?
    let steps: Int?
    let indoor: Bool?
    let details: WorkoutDetails?
}

struct WorkoutSyncRequest: Codable, Sendable {
    let workouts: [WorkoutSyncEntry]
}

struct WorkoutHistoryResponse: Codable, Sendable {
    let total: Int
    let workouts: [WorkoutSyncEntry]
}

struct HeartRateBar: Identifiable, Sendable {
    let date: Date
    let bpm: Double

    var id: Date { date }
}

struct WorkoutSeriesPoint: Identifiable, Sendable {
    let date: Date
    let value: Double

    var id: Date { date }
}

enum WorkoutSeriesKind: String, Sendable, Hashable {
    case speed
    case cadence
    case power
}

struct WorkoutSeries: Sendable {
    let kind: WorkoutSeriesKind
    let points: [WorkoutSeriesPoint]
}

enum WorkoutMapper {

    private static var isoFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private static var isoFormatterNoFraction: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    static func toEntry(_ workout: HealthKitWorkout) -> WorkoutSyncEntry {
           WorkoutSyncEntry(
               healthKitWorkoutId: workout.id.uuidString,
               type: workout.workoutType,
               startDate: isoFormatter.string(from: workout.startDate),
               endDate: isoFormatter.string(from: workout.endDate),
               durationSeconds: workout.durationSeconds,
               caloriesBurned: workout.caloriesBurned,
               distanceMeters: workout.distanceMeters,
               heartRateAvg: workout.heartRateAvg,
               heartRateMax: workout.heartRateMax,
               heartRateMin: workout.heartRateMin,
               avgSpeedMps: workout.avgSpeedMps,
               maxSpeedMps: workout.maxSpeedMps,
               avgCadence: workout.avgCadence,
               maxCadence: workout.maxCadence,
               avgPowerWatts: workout.avgPowerWatts,
               maxPowerWatts: workout.maxPowerWatts,
               elevationGainMeters: workout.elevationGainMeters,
               steps: workout.steps,
               indoor: workout.indoor,
               details: workout.details
           )
       }

    static func isoString(from date: Date) -> String {
        isoFormatter.string(from: date)
    }

    static func toWorkout(_ entry: WorkoutSyncEntry) -> HealthKitWorkout? {
        guard
            let start = parseDate(entry.startDate),
            let end = parseDate(entry.endDate),
            let id = UUID(uuidString: entry.healthKitWorkoutId)
        else { return nil }

        return HealthKitWorkout(
                   id: id,
                   workoutType: entry.type,
                   startDate: start,
                   endDate: end,
                   durationSeconds: entry.durationSeconds,
                   caloriesBurned: entry.caloriesBurned,
                   distanceMeters: entry.distanceMeters,
                   heartRateAvg: entry.heartRateAvg,
                   heartRateMax: entry.heartRateMax,
                   heartRateMin: entry.heartRateMin,
                   avgSpeedMps: entry.avgSpeedMps,
                   maxSpeedMps: entry.maxSpeedMps,
                   avgCadence: entry.avgCadence,
                   maxCadence: entry.maxCadence,
                   avgPowerWatts: entry.avgPowerWatts,
                   maxPowerWatts: entry.maxPowerWatts,
                   elevationGainMeters: entry.elevationGainMeters,
                   steps: entry.steps,
                   indoor: entry.indoor,
                   details: entry.details
               )
    }

    private static func parseDate(_ string: String) -> Date? {
        isoFormatter.date(from: string) ?? isoFormatterNoFraction.date(from: string)
    }
}

enum WorkoutFormatter {

    static func minuteBars(points: [HeartRatePoint], maxBars: Int = 48) -> [HeartRateBar] {
        guard !points.isEmpty else { return [] }
        let sorted = points.sorted { $0.startDate < $1.startDate }
        guard let first = sorted.first, let last = sorted.last else { return [] }

        let span = max(last.startDate.timeIntervalSince(first.startDate), 60)
        let bucketMinutes = max(1, Int(ceil(span / Double(maxBars * 60))))

        var buckets: [Int: (count: Int, sum: Double, date: Date)] = [:]
        let interval = TimeInterval(bucketMinutes) * 60
        for point in sorted {
            let index = Int(point.startDate.timeIntervalSinceReferenceDate / interval)
            var entry = buckets[index] ?? (count: 0, sum: 0, date: point.startDate)
            entry.count += 1
            entry.sum += point.bpm
            buckets[index] = entry
        }

        return buckets.keys.sorted().compactMap { index in
            guard let entry = buckets[index], entry.count > 0 else { return nil }
            return HeartRateBar(date: entry.date, bpm: entry.sum / Double(entry.count))
        }
    }

    static func icon(for type: String) -> String {
        switch type {
        case "Running": return "figure.run"
        case "Walking": return "figure.walk"
        case "Cycling": return "figure.outdoor.cycle"
        case "Swimming": return "figure.pool.swim"
        case "Yoga": return "figure.yoga"
        case "HIIT": return "figure.highintensity.intervaltraining"
        case "Strength Training",
             "Functional Strength Training",
             "Core Training": return "dumbbell.fill"
        case "Hiking": return "figure.hiking"
        case "Rowing": return "figure.rower"
        case "Elliptical": return "figure.elliptical"
        case "Stair Climbing": return "figure.stair.stepper"
        case "Dance": return "figure.dance"
        case "Jump Rope": return "figure.jumprope"
        default: return "figure.mixed.cardio"
        }
    }

    static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: date)
    }

    static func formattedDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        return String(format: "%dm", minutes)
    }
}

struct HeartRatePoint: Equatable, Sendable, Identifiable {
    let startDate: Date
    let bpm: Double

    var id: Date { startDate }
}


