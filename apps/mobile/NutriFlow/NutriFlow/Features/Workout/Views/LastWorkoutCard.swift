//
//  LastWorkoutCard.swift
//  Nutriflow
//
//  Created by Artem on 05.09.2026.
//

import SwiftUI

struct LastWorkoutCard: View {
    let workout: HealthKitWorkout?
    let state: LastWorkoutState
    let healthAccessDenied: Bool
    let onOpenSettings: () -> Void
    let onTap: () -> Void
    let onRetry: () -> Void
    var weeklyWorkoutsGoal: Int? = nil
    var weeklyWorkoutMinutesGoal: Int? = nil
    var weekWorkoutsCount: Int = 0
    var weekWorkoutMinutes: Int = 0
    
    var body: some View {
        if healthAccessDenied {
            deniedPrompt
        } else if case .error(let error) = state, workout == nil {
            WorkoutLatestErrorNotice(error: error, onRetry: onRetry)
        } else if state == .loading, workout == nil {
            workoutSkeleton
                .appGlassSurface(level: .prominent)
                .modifier(SkeletonShimmer())
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
        
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .padding()
        .frame(maxWidth: .infinity)
        .appGlassSurface(level: .prominent)
    }

    
    private var workoutSkeleton: some View {
        VStack(spacing: 12) {
            // Workout header
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(AppColors.textSecondary.opacity(0.12))
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    skeletonPlaceholder(width: 105, height: 17)
                    skeletonPlaceholder(width: 125, height: 12)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    skeletonPlaceholder(width: 58, height: 14)

                    HStack(spacing: 10) {
                        skeletonPlaceholder(width: 48, height: 11)
                        skeletonPlaceholder(width: 45, height: 11)
                    }
                }
            }

            if let goal = weeklyWorkoutsGoal, goal > 0 {
                activityGoalSkeleton
            }

            if let goal = weeklyWorkoutMinutesGoal, goal > 0 {
                activityGoalSkeleton
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading workout data")
    }

    private struct SkeletonShimmer: ViewModifier {
        @State private var isAnimating = false

        func body(content: Content) -> some View {
            content
                .overlay {
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        .white.opacity(0.10),
                                        .clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * 0.5)
                            .offset(
                                x: isAnimating
                                    ? geometry.size.width
                                    : -geometry.size.width
                            )
                    }
                    .clipped()
                    .allowsHitTesting(false)
                }
                .onAppear {
                    withAnimation(
                        .linear(duration: 1.4)
                            .repeatForever(autoreverses: false)
                    ) {
                        isAnimating = true
                    }
                }
        }
    }
    
    private var activityGoalSkeleton: some View {
        HStack(spacing: 10) {
            // Progress column: 46 × 70
            ZStack(alignment: .bottom) {
                RoundedRectangle(
                    cornerRadius: 15,
                    style: .continuous
                )
                .fill(AppColors.textSecondary.opacity(0.10))
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 15,
                        style: .continuous
                    )
                    .strokeBorder(
                        AppColors.textSecondary.opacity(0.10),
                        lineWidth: 1.2
                    )
                }

                RoundedRectangle(
                    cornerRadius: 15,
                    style: .continuous
                )
                .fill(AppColors.textSecondary.opacity(0.14))
                .frame(height: 35)

                Circle()
                    .fill(AppColors.textSecondary.opacity(0.18))
                    .frame(width: 17, height: 17)
                    .padding(.bottom, 7)
            }
            .frame(width: 46, height: 70)

            // Goal information
            VStack(alignment: .leading, spacing: 3) {
                skeletonPlaceholder(width: 65, height: 12)
                skeletonPlaceholder(width: 115, height: 14)
                skeletonPlaceholder(width: 55, height: 24)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
            .fill(AppColors.textSecondary.opacity(0.06))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
            .stroke(
                AppColors.textSecondary.opacity(0.08),
                lineWidth: 0.8
            )
        }
    }

    private func skeletonPlaceholder(
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(AppColors.textSecondary.opacity(0.12))
            .frame(width: width, height: height)
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
        .appGlassSurface()
    }
}

private struct WorkoutLatestErrorNotice: View {
    let error: AppError
    let onRetry: () -> Void

    var body: some View {
        if error == .unknown {
            VStack(alignment: .leading, spacing: 8) {
                Text("Couldn’t load the latest workout from Apple Health.")
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
                Button("Try again", action: onRetry)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(AppColors.accent)
                    .buttonStyle(.plain)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .appGlassSurface()
        } else {
            ErrorView(error: error, onRetry: onRetry)
        }
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
        state: .loaded,
        healthAccessDenied: false,
        onOpenSettings: {},
        onTap: {},
        onRetry: {},
        weeklyWorkoutsGoal: 5,
        weeklyWorkoutMinutesGoal: 150,
        weekWorkoutsCount: 3,
        weekWorkoutMinutes: 95
    )
    .padding()
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}

#Preview("Loading") {
    LastWorkoutCard(
        workout: nil,
        state: .loading,
        healthAccessDenied: false,
        onOpenSettings: {},
        onTap: {},
        onRetry: {},
        weeklyWorkoutsGoal: 5,
        weeklyWorkoutMinutesGoal: 150,
        weekWorkoutsCount: 0,
        weekWorkoutMinutes: 0
    )
    .padding()
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
