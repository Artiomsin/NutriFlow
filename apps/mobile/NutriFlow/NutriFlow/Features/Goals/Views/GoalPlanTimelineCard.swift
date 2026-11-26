import SwiftUI

/// Presents the API's safe, applied plan rather than echoing the form values.
struct GoalPlanTimelineCard: View {
    let preview: GoalsPreview
    let completion: GoalEstimatedCompletion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Plan timeline", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)

            if let rate = appliedRate {
                timelineRow(
                    title: "Applied weekly pace",
                    value: weeklyPaceText(rate),
                    systemImage: "figure.run"
                )
            }

            if let targetDate = displayDate(preview.basis?.targetDate) {
                timelineRow(
                    title: "Your target date",
                    value: targetDate,
                    systemImage: "calendar"
                )
            }

            timelineRow(
                title: "Estimated completion",
                value: displayDate(completion.plannedDate ?? completion.byTrendDate) ?? "Calculated from your pace",
                systemImage: "calendar.badge.clock"
            )

            Label(explanation, systemImage: messageIcon)
                .font(.footnote)
                .foregroundStyle(messageColor)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appGlassSurface(level: .inset)
        }
        .padding(16)
        .appGlassSurface()
    }

    private var appliedRate: Double? {
        preview.calories?.targetRateKgPerWeek
            ?? completion.targetRateKgPerWeek
            ?? preview.basis?.weeklyRateKg
    }

    private var warnings: Set<String> {
        Set(preview.calories?.warnings ?? [])
    }

    private var isSafetyAdjustment: Bool {
        warnings.contains("target_rate_limited_to_safe_maximum")
            || warnings.contains("derived_rate_limited_to_safe_maximum")
            || warnings.contains("target_rate_increased_to_safe_minimum")
            || warnings.contains("derived_rate_increased_to_safe_minimum")
    }

    private var explanation: String {
        let pace = appliedRate.map(weeklyPaceText) ?? "the recommended rate"

        if warnings.contains("target_rate_limited_to_safe_maximum")
            || warnings.contains("derived_rate_limited_to_safe_maximum") {
            return "Your selected date would require a faster pace than is considered safe. The plan uses a safer pace of \(pace)."
        }
        if warnings.contains("target_rate_increased_to_safe_minimum")
            || warnings.contains("derived_rate_increased_to_safe_minimum") {
            return "Your selected date would require a pace below the safe minimum. The plan uses \(pace) instead."
        }
        switch preview.calories?.paceSource {
        case "explicit_rate":
            return "Your selected weekly pace takes priority over the target date, so the estimate follows that pace."
        case "target_date":
            return "The weekly pace was calculated from your target date. This is still an estimate."
        default:
            return "This estimate is based on your current weight, target, and selected pace."
        }
    }

    private var messageIcon: String {
        isSafetyAdjustment ? "shield.lefthalf.filled" : "info.circle.fill"
    }

    private var messageColor: Color {
        isSafetyAdjustment ? AppColors.warning : AppColors.textSecondary
    }

    private func timelineRow(title: String, value: String, systemImage: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(AppColors.accent)
                .frame(width: 20)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func weeklyPaceText(_ rate: Double) -> String {
        let value = abs(rate).formatted(.number.precision(.fractionLength(0...2)))
        return "\(value) kg/week"
    }

    private func displayDate(_ value: String?) -> String? {
        guard let value else { return nil }
        let date = AppDate.dateOnlyFormatter().date(from: value) ?? AppDate.parseISO(value)
        guard let date else { return value }
        return AppDate.displayFormatter("d MMMM yyyy").string(from: date)
    }
}
