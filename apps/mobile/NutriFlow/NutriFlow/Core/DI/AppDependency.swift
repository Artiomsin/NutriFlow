import Foundation

protocol AppDependency {

    var httpClient: HTTPClient { get }

    var tokenStorage: TokenStorage { get }

    var sessionService: AuthSessionService { get }
    var refreshService: AuthRefreshService { get }
    var sessionBootstrapService: SessionBootstrapService { get }

    var authService: AuthServiceProtocol { get }
    var profileService: ProfileServiceProtocol { get }
    var userService: UserServiceProtocol { get }
    var foodService: FoodServiceProtocol { get }
    var waterTrackingService: WaterTrackingServiceProtocol { get }
    var dailySummaryService: DailySummaryServiceProtocol { get }
    var goalsService: GoalsServiceProtocol { get }
    var analyticsService: AnalyticsServiceProtocol { get }
    var analyticsManager: AnalyticsManager { get }
    var cacheService: CacheService { get }
    var googleSignInService: GoogleSignInService { get }
    var healthKitService: HealthKitServiceProtocol { get }
    var activityService: ActivityServiceProtocol { get }
    var activitySync: ActivitySyncProtocol { get }

}
