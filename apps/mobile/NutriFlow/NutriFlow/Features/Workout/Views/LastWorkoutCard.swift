//
//  LastWorkoutCard.swift
//  Nutriflow
//
//  Created by Artem on 05.09.2026.
//

import SwiftUI

struct LastWorkoutCard: View {
    let workout: HealthKitWorkout?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: WorkoutFormatter.icon(for: workout?.workoutType ?? "Workout"))
                    .font(.title2)
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.accent.opacity(0.12))
                    .cornerRadius(AppTheme.cornerRadiusMedium)

                VStack(alignment: .leading, spacing: 4) {
                    Text(workout?.workoutType ?? "Workouts")
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                    if let workout {
                        Text(WorkoutFormatter.formattedDate(workout.startDate))
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Spacer()

                if let workout {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(WorkoutFormatter.formattedDuration(workout.durationSeconds))
                            .font(.footnote)
                            .foregroundColor(AppTheme.textPrimary)
                        HStack(spacing: 10) {
                            if let kcal = workout.caloriesBurned {
                                Text("\(Int(kcal)) kcal")
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            if let distance = workout.distanceMeters, distance > 0 {
                                Text(String(format: "%.1f km", distance / 1000))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                        .font(.caption)
                    }
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadiusMedium)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LastWorkoutCard(
        workout: HealthKitWorkout(
            id: UUID(),
            workoutType: "Running",
            startDate: Date(),
            endDate: Date().addingTimeInterval(2520),
            durationSeconds: 2520,
            caloriesBurned: 386,
            distanceMeters: 5200
        ),
        onTap: {}
    )
    .padding()
    .background(AppTheme.background)
    .preferredColorScheme(.dark)
}