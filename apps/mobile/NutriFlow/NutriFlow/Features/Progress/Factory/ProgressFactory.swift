import SwiftUI

enum ProgressFactory {
    @MainActor @ViewBuilder
    static func make(
        coordinator: AppCoordinator,
        container: AppDependency,
        periodState: PeriodState,
        analyticsVM: AnalyticsViewModel
    ) -> some View {
        let chartVM = ProgressChartViewModel(
            coordinator: coordinator,
            service: container.dailySummaryService,
            periodState: periodState,
            foodService: container.foodService,
            waterService: container.waterTrackingService,
            goalsService: container.goalsService
        )
        ProgressDashboardView(
            analyticsVM: analyticsVM,
            chartVM: chartVM,
            periodState: periodState
        )
    }
}
