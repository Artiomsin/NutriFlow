//
//  WorkoutStartView.swift
//  Nutriflow
//
//  Created by Artem on 07.09.2026.
//

import SwiftUI

struct WorkoutStartView: View {
    @Bindable var vm: ActiveWorkoutViewModel
    let onStart: (TrackableWorkout) -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(TrackableWorkout.allCases) { workout in
                        Button {
                            onStart(workout)
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: workout.iconName)
                                    .font(.title3)
                                    .foregroundColor(AppTheme.accent)
                                    .frame(width: 44, height: 44)
                                    .background(AppTheme.accent.opacity(0.12))
                                    .cornerRadius(AppTheme.cornerRadiusMedium)

                                Text(workout.title)
                                    .font(.headline)
                                    .foregroundColor(AppTheme.textPrimary)

                                Spacer()

                                Image(systemName: "play.fill")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.accent)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(AppTheme.cardBackground)
                            .cornerRadius(AppTheme.cornerRadiusMedium)
                        }
                    }
                }
                .padding(AppTheme.paddingHorizontal)
            }
            .background(AppTheme.background)
            .navigationTitle("Start Workout")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        WorkoutStartView(
            vm: ActiveWorkoutViewModel(healthKit: MockHealthKit())
        ) { _ in }
    }
    .preferredColorScheme(.dark)
}
