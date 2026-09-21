//
//  LastWorkoutCard.swift
//  Nutriflow
//
//  Created by Artem on 05.09.2026.
//

import SwiftUI

struct LastWorkoutCard: View {
    let workout: HealthKitWorkout?
    let healthAccessDenied: Bool
    let onOpenSettings: () -> Void
    let onTap: () -> Void
    var weeklyWorkoutsGoal: Int? = nil
    var weeklyWorkoutMinutesGoal: Int? = nil
    var weekWorkoutsCount: Int = 0
    var weekWorkoutMinutes: Int = 0

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if healthAccessDenied {
            deniedPrompt
        } else {
            workoutContent
        }
    }

    private var workoutContent: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    Image(systemName: WorkoutFormatter.icon(for: workout?.workoutType ?? "Workout"))
                        .font(.title2)
                        .foregroundColor(AppColors.accent)
                        .frame(width: 44, height: 44)
                        .background(AppColors.accent.opacity(0.12))
                        .cornerRadius(AppRadius.medium)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout?.workoutType ?? "Workouts")
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        if let workout {
                            Text(WorkoutFormatter.formattedDate(workout.startDate))
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    Spacer()

                    if let workout {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(WorkoutFormatter.formattedDuration(workout.durationSeconds))
                                .font(.footnote)
                                .foregroundColor(AppColors.textPrimary)
                            HStack(spacing: 10) {
                                if let kcal = workout.caloriesBurned {
                                    Text("\(Int(kcal)) kcal")
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                if let distance = workout.distanceMeters, distance > 0 {
                                    Text(String(format: "%.1f km", distance / 1000))
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }
                            .font(.caption)
                        }
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                if let goal = weeklyWorkoutsGoal, goal > 0 {
                    ActivityGoalRow(
                        icon: "figure.run",
                        label: "Workouts this week",
                        current: weekWorkoutsCount,
                        goal: goal,
                        color: .blue,
                        unit: "",
                        hasGlass: false
                    )
                }
                if let goal = weeklyWorkoutMinutesGoal, goal > 0 {
                    ActivityGoalRow(
                        icon: "timer",
                        label: "Minutes this week",
                        current: weekWorkoutMinutes,
                        goal: goal,
                        color: .teal,
                        unit: "min",
                        hasGlass: false
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppColors.surface)
        .cornerRadius(AppRadius.medium)
        .shadow(
            color: colorScheme == .dark ? .black.opacity(0.45) : .black.opacity(0.06),
            radius: colorScheme == .dark ? 14 : 5,
            y: colorScheme == .dark ? 8 : 2
        )
    }

    private var deniedPrompt: some View {
        HStack {
            Image(systemName: "heart.slash")
                .foregroundColor(AppColors.textSecondary)
            Text("Workouts access is off. Enable Apple Health in Settings.")
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Button("Settings", action: onOpenSettings)
                .font(.caption)
                .foregroundColor(AppColors.accent)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppColors.surface)
        .cornerRadius(AppRadius.medium)
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
        healthAccessDenied: false,
        onOpenSettings: {},
        onTap: {},
        weeklyWorkoutsGoal: 5,
        weeklyWorkoutMinutesGoal: 150,
        weekWorkoutsCount: 3,
        weekWorkoutMinutes: 95
    )
    .padding()
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
