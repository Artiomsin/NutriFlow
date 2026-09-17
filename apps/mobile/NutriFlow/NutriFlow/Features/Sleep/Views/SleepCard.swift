//
//  SleepCard.swift
//  Nutriflow
//

import SwiftUI

@MainActor
struct SleepCard: View {

    @Bindable var vm: SleepViewModel
    var onTap: () -> Void = {}
    var goals: UserGoals? = nil

    var body: some View {
        switch vm.state {
        case .idle, .loading:
            HStack {
                ProgressView().tint(AppTheme.accent)
                Text("Loading sleep...")
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadiusMedium)
        case .needsAccess:
            accessPrompt
        case .denied:
            deniedPrompt
        case .empty:
            emptyPrompt
                .contentShape(Rectangle())
                .onTapGesture { onTap() }
        case .error:
            settingsPrompt
        case .loaded(let nights):
            if let lastNight = nights.first {
                sleepContent(lastNight)
                    .contentShape(Rectangle())
                    .onTapGesture { onTap() }
            } else {
                emptyPrompt
                    .contentShape(Rectangle())
                    .onTapGesture { onTap() }
            }
        }
    }

    private var accessPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.largeTitle)
                .foregroundColor(AppTheme.accent)
            Text("Track your sleep")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            Text("Connect Apple Health to see your sleep stages and quality.")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await vm.connectTapped() }
            } label: {
                Text("Connect Health")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.accent)
                    .cornerRadius(AppTheme.cornerRadiusMedium)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }

    private var deniedPrompt: some View {
        HStack {
            Image(systemName: "moon.zzz")
                .foregroundColor(AppTheme.textSecondary)
            Text("Sleep access is off. Enable Apple Health in Settings.")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
            Button("Settings") {
                vm.openSettings()
            }
            .font(.caption)
            .foregroundColor(AppTheme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }

    private var emptyPrompt: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "moon")
                        .foregroundColor(AppTheme.textSecondary)
                    Text("No sleep data for last night yet")
                        .font(.footnote)
                        .foregroundColor(AppTheme.textSecondary)
                }
                Text("Tap to see history")
                    .font(.caption2)
                    .foregroundColor(AppTheme.textSecondary.opacity(0.7))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }

    private var settingsPrompt: some View {
        HStack {
            Text("Sleep data unavailable")
                .font(.footnote)
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
            Button("Settings") {
                vm.openSettings()
            }
            .font(.caption)
            .foregroundColor(AppTheme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }

    private func sleepContent(_ sleep: HealthKitSleep) -> some View {
        VStack(spacing: 12) {
            HStack {
                Label("Sleep", systemImage: "moon.zzz.fill")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                if let hr = sleep.heartRateAvg {
                    Label(String(format: "%.0f bpm", hr), systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            HStack(spacing: 16) {
                SleepMetric(
                    icon: "bed.double.fill",
                    value: hours(sleep.asleepSeconds),
                    unit: "asleep"
                )
                SleepMetric(
                    icon: "moon",
                    value: hours(sleep.timeInBedSeconds),
                    unit: "in bed"
                )
                if sleep.awakeSeconds > 0 {
                    SleepMetric(
                        icon: "alarm",
                        value: hours(sleep.awakeSeconds),
                        unit: "awake"
                    )
                }
            }

            StageBar(
                core: sleep.coreSeconds,
                deep: sleep.deepSeconds,
                rem: sleep.remSeconds,
                unspecified: sleep.unspecifiedSeconds
            )

            let stats = statistics(sleep)
            if !stats.isEmpty {
                Text(stats)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                    
            }

            if let minMinutes = goals?.nightlySleepMinMinutes,
               let maxMinutes = goals?.nightlySleepMaxMinutes,
               maxMinutes > 0 {
                ActivityGoalRow(
                    icon: "moon.zzz.fill",
                    label: "Sleep goal",
                    current: Int(sleep.asleepSeconds / 60),
                    goal: maxMinutes,
                    color: .indigo,
                    displayCurrent: hours(sleep.asleepSeconds),
                    displayGoal: sleepGoalRangeText(min: minMinutes, max: maxMinutes),
                    hasGlass: false
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }

    private func hours(_ seconds: Double) -> String {
        String(format: "%.1fh", seconds / 3600)
    }

    private func sleepGoalRangeText(min: Int, max: Int) -> String {
        String(format: "%.0f–%.0f h", Double(min) / 60, Double(max) / 60)
    }

    private func statistics(_ sleep: HealthKitSleep) -> String {
        var parts: [String] = []
        if sleep.awakenings > 0 { parts.append("\(sleep.awakenings) awakenings") }
        if let efficiency = sleep.efficiency { parts.append("\(Int(efficiency))% efficiency") }
        if sleep.segmentCount > 0 { parts.append("\(sleep.segmentCount) segments") }
        return parts.joined(separator: " · ")
    }
}

private struct SleepMetric: View {
    let icon: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.accent)
            Text(value)
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            Text(unit)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StageBar: View {
    let core: Double
    let deep: Double
    let rem: Double
    let unspecified: Double

    private var total: Double {
        core + deep + rem + unspecified
    }

    var body: some View {
        if total > 0 {
            VStack(spacing: 10) {
                HStack(spacing: 2) {
                    if core > 0 {
                        stage(AppTheme.accent.opacity(0.45))
                    }
                    if deep > 0 {
                        stage(AppTheme.accent.opacity(0.75))
                    }
                    if rem > 0 {
                        stage(AppTheme.accent)
                    }
                    if unspecified > 0 {
                        stage(AppTheme.textSecondary.opacity(0.5))
                    }
                }
                HStack(spacing: 8) {
                    legendItem("Core", AppTheme.accent.opacity(0.45))
                    legendItem("Deep", AppTheme.accent.opacity(0.75))
                    legendItem("REM", AppTheme.accent)
                    if unspecified > 0 {
                        legendItem("Other", AppTheme.textSecondary.opacity(0.5))
                    }
                }
            }
        }
    }

    private func stage(_ color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(maxWidth: .infinity)
            .frame(height: 8)
    }

    private func legendItem(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
        }
        .font(.caption2)
        .foregroundColor(AppTheme.textSecondary)
    }
}

#Preview("Loaded") {
    let vm = SleepViewModel(
        coordinator: SleepSyncCoordinator(
            healthKitService: MockSleepHealthKit(),
            sleepService: MockSleepService(),
            cacheService: CacheService()
        )
    )
    vm.state = .loaded([HealthKitSleep(
        id: UUID(),
        startDate: Date(),
        endDate: Date().addingTimeInterval(8 * 3600),
        timeInBedSeconds: 7.5 * 3600,
        asleepSeconds: 7 * 3600,
        awakeSeconds: 0.5 * 3600,
        coreSeconds: 4 * 3600,
        deepSeconds: 1.5 * 3600,
        remSeconds: 1.5 * 3600,
        unspecifiedSeconds: 0,
        awakenings: 1,
        segmentCount: 5,
        onsetLatencySeconds: 600,
        efficiency: 93,
        heartRateAvg: 58,
        segments: []
    )])
    return SleepCard(vm: vm)
        .padding()
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
}

#Preview("Needs Access") {
    let vm = SleepViewModel(
        coordinator: SleepSyncCoordinator(
            healthKitService: MockSleepHealthKit(),
            sleepService: MockSleepService(),
            cacheService: CacheService()
        )
    )
    vm.state = .needsAccess
    return SleepCard(vm: vm)
        .padding()
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
}
