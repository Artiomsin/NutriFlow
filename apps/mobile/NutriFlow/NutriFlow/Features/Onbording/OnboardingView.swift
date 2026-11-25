import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(onComplete: @escaping () -> Void, initialPage: Int = 0) {
        self.onComplete = onComplete
        _currentPage = State(initialValue: initialPage)
    }

    private let pages: [OnboardingPageData] = [
        .init(
            icon: "fork.knife",
            eyebrow: "YOUR DAILY BASELINE",
            title: "Food logging that fits real life",
            description: "Log meals quickly, understand your macros, and keep the day moving.",
            highlights: ["Smart meal logging", "Clear macro breakdown"],
            accent: AppColors.accent
        ),
        .init(
            icon: "drop.fill",
            eyebrow: "SMALL HABITS",
            title: "Hydration, without the mental load",
            description: "See a simple daily water target and stay on track one glass at a time.",
            highlights: ["Personal daily target", "Gentle reminders"],
            accent: AppColors.info
        ),
        .init(
            icon: "chart.line.uptrend.xyaxis",
            eyebrow: "PROGRESS, EXPLAINED",
            title: "See the trend behind every day",
            description: "Your progress is presented as a clear story, not a wall of numbers.",
            highlights: ["Weight trends", "Goal forecasts"],
            accent: AppColors.success
        ),
        .init(
            icon: "sparkles",
            eyebrow: "READY WHEN YOU ARE",
            title: "Build a plan you can keep",
            description: "Set up your profile next. NutriFlow will tailor goals around your routine.",
            highlights: ["Personalized goals", "Adjust as life changes"],
            accent: AppColors.accentSecondary
        )
    ]

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            ambientBackground

            VStack(spacing: 0) {
                header

                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        OnboardingPageCard(page: page, isActive: currentPage == index)
                            .tag(index)
                            .padding(.horizontal, 24)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .snappy, value: currentPage)

                footer
            }
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .tint(AppColors.accent)
    }

    private var ambientBackground: some View {
        GeometryReader { proxy in
            Circle()
                .fill(pages[currentPage].accent.opacity(0.18))
                .frame(width: proxy.size.width * 0.9)
                .blur(radius: 40)
                .offset(x: proxy.size.width * 0.38, y: -proxy.size.height * 0.22)

            Circle()
                .fill(AppColors.glassHighlight.opacity(0.15))
                .frame(width: proxy.size.width * 0.7)
                .blur(radius: 48)
                .offset(x: -proxy.size.width * 0.4, y: proxy.size.height * 0.7)
        }
        .allowsHitTesting(false)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: currentPage)
    }

    private var header: some View {
        HStack {
            Text("NUTRIFLOW")
                .font(.caption.weight(.bold))
                .tracking(1.8)
                .foregroundStyle(AppColors.textSecondary)

            Spacer()

            Button("Skip", action: finish)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
                .accessibilityHint("Skips the introduction and continues to sign in.")
        }
        .padding(.horizontal, 24)
    }

    private var footer: some View {
        VStack(spacing: 20) {
            OnboardingPageIndicator(
                currentPage: currentPage,
                totalPages: pages.count,
                tint: pages[currentPage].accent
            )

            Button(action: advance) {
                HStack(spacing: 10) {
                    Text(currentPage == pages.indices.last ? "Set up my plan" : "Continue")
                    Image(systemName: currentPage == pages.indices.last ? "arrow.right" : "chevron.right")
                }
                .font(.headline)
                .foregroundStyle(AppColors.accentOnPrimary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
                .background(pages[currentPage].accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(currentPage == pages.indices.last ? "Set up my plan" : "Continue")
            .padding(.horizontal, 24)
        }
    }

    private func advance() {
        guard currentPage < pages.count - 1 else {
            finish()
            return
        }

        withAnimation(reduceMotion ? nil : .snappy) {
            currentPage += 1
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "onboardingShown")
        onComplete()
    }
}

private struct OnboardingPageCard: View {
    let page: OnboardingPageData
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 20)

            Image(systemName: page.icon)
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(page.accent)
                .frame(width: 96, height: 96)
                .background(page.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .accessibilityHidden(true)
                .scaleEffect(isActive || reduceMotion ? 1 : 0.85)
                .opacity(isActive ? 1 : 0.5)

            Spacer(minLength: 44)

            Text(page.eyebrow)
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(page.accent)

            Text(page.title)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(AppColors.textPrimary)
                .padding(.top, 12)
                .fixedSize(horizontal: false, vertical: true)

            Text(page.description)
                .font(.body)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(4)
                .padding(.top, 14)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(page.highlights, id: \.self) { highlight in
                    Label(highlight, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.textPrimary)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(page.accent)
                }
            }
            .padding(.top, 30)
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppColors.border.opacity(0.8), lineWidth: 1)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct OnboardingPageIndicator: View {
    let currentPage: Int
    let totalPages: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? tint : AppColors.textSecondary.opacity(0.25))
                    .frame(width: index == currentPage ? 28 : 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(currentPage + 1) of \(totalPages)")
    }
}

private struct OnboardingPageData: Identifiable {
    let id = UUID()
    let icon: String
    let eyebrow: String
    let title: String
    let description: String
    let highlights: [String]
    let accent: Color
}

#Preview("Onboarding — Start") {
    OnboardingView(onComplete: {})
}

#Preview("Onboarding — Final CTA") {
    OnboardingView(onComplete: {}, initialPage: 3)
}
