import SwiftUI

enum ProgressFactory {
    @MainActor @ViewBuilder
    static func make(
        coordinator: AppCoordinator,
        container: AppDependency,
        periodState: PeriodState,
        isGuest: Bool
    ) -> some View {
        let cache = container.cacheService
        let analyticsVM = AnalyticsViewModel(
            coordinator: coordinator,
            service: container.analyticsService,
            periodState: periodState,
            cacheService: cache
        )
        let chartVM = ProgressChartViewModel(
            coordinator: coordinator,
            service: container.dailySummaryService,
            periodState: periodState,
            foodService: container.foodService,
            waterService: container.waterTrackingService,
            goalsService: container.goalsService,
            cacheService: cache
        )
        ProgressDashboardView(
            analyticsVM: analyticsVM,
            chartVM: chartVM,
            periodState: periodState,
            isGuest: isGuest
        )
    }
}
