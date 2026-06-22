import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0
    
    private let pages: [OnboardingPageData] = [
        OnboardingPageData(
            icon: "fork.knife",
            title: "Отслеживай питание",
            subtitle: "Контролируй КБЖУ с AI",
            description: "Просто сфотографируй еду — нейросеть определит калории, белки, жиры и углеводы автоматически.",
            statValue: "98%",
            statLabel: "точность",
            feature: "База из 2M+ продуктов"
        ),
        OnboardingPageData(
            icon: "drop",
            title: "Умный гидратор",
            subtitle: "Пей воду осознанно",
            description: "Персональная норма воды с учётом твоего веса, активности и погоды. Напоминания каждый час.",
            statValue: "2.5L",
            statLabel: "средняя норма",
            feature: "Синхронизация с HealthKit"
        ),
        OnboardingPageData(
            icon: "chart.line.uptrend.xyaxis",
            title: "Глубокая аналитика",
            subtitle: "Видишь свой прогресс",
            description: "Красивые графики веса, процента жира и мышечной массы. Прогноз на 30 дней вперёд.",
            statValue: "24/7",
            statLabel: "мониторинг",
            feature: "Экспорт в PDF"
        ),
        OnboardingPageData(
            icon: "crown",
            title: "Достижения",
            subtitle: "Мотивация каждый день",
            description: "Зарабатывай бейджи, соревнуйся с друзьями и получай персональные челленджи.",
            statValue: "150+",
            statLabel: "достижений",
            feature: "Еженедельные турниры"
        )
    ]
    
    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ModernPageIndicator(currentPage: currentPage, totalPages: pages.count)
                    .padding(.top, 60)
                    .padding(.horizontal, 24)
                
                Spacer(minLength: 20)
                
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        DarkOnboardingCard(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                Spacer(minLength: 30)

                Button {
                    if currentPage < pages.count - 1 {
                        currentPage += 1
                    } else {
                        UserDefaults.standard.set(true, forKey: "onboardingShown")
                        onComplete()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text(currentPage < pages.count - 1 ? "Далее" : "Начать")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))

                        Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(color: AppTheme.accent.opacity(0.3), radius: 12, x: 0, y: 5)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct ModernPageIndicator: View {
    let currentPage: Int
    let totalPages: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(index == currentPage ? AppTheme.accent : AppTheme.textSecondary.opacity(0.3))
                    .frame(width: index == currentPage ? 28 : 8, height: 8)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentPage)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct DarkOnboardingCard: View {
    let page: OnboardingPageData
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: page.icon)
                .font(.system(size: 60, weight: .medium))
                .foregroundColor(AppTheme.accent)
                .scaleEffect(isAnimating ? 1 : 0.8)
                .opacity(isAnimating ? 1 : 0)
            
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(page.subtitle)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.accent.opacity(0.9))
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(isAnimating ? 1 : 0)
            .offset(y: isAnimating ? 0 : 20)
            
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text(page.statValue)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(page.statLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(AppTheme.cardBorder)
                    .frame(width: 1, height: 40)
                
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.accent)
                    Text(page.feature)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)
            .opacity(isAnimating ? 1 : 0)
            .offset(y: isAnimating ? 0 : 30)
        }
        .padding(.vertical, 20)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                isAnimating = true
            }
        }
    }
}

struct OnboardingPageData {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let statValue: String
    let statLabel: String
    let feature: String
}

#Preview("Тёмный онбординг") {
    OnboardingView(onComplete: {})
        .preferredColorScheme(.dark)
}
