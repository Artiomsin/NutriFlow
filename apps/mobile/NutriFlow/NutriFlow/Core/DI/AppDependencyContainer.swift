import Foundation

final class AppDependencyContainer: AppDependency {

    let httpClient: HTTPClient

    let tokenStorage: TokenStorage

    let sessionService: AuthSessionService
    let refreshService: AuthRefreshService
    let sessionBootstrapService: SessionBootstrapService

    let authService: AuthServiceProtocol
    let profileService: ProfileServiceProtocol
    let userService: UserServiceProtocol
    let foodService: FoodServiceProtocol
    let waterTrackingService: WaterTrackingServiceProtocol
    let dailySummaryService: DailySummaryServiceProtocol
    let goalsService: GoalsServiceProtocol
    let analyticsService: AnalyticsServiceProtocol
    let analyticsManager: AnalyticsManager
    let cacheService: CacheService
    let googleSignInService: GoogleSignInService
    let activityService: ActivityServiceProtocol
    let workoutService: WorkoutServiceProtocol
    let sleepService: SleepServiceProtocol
    let activityHealthKitService: ActivityHealthKitServiceProtocol
    let workoutHealthKitService: WorkoutHealthKitServiceProtocol
    let sleepHealthKitService: SleepHealthKitServiceProtocol
    let activitySync: ActivitySyncProtocol


    init() {
        self.cacheService = CacheService()
        let keychain = KeychainService()
        self.tokenStorage = KeychainTokenStorage(keychain: keychain)

        let session = AuthSessionService(tokenStorage: tokenStorage)
        self.sessionService = session

        let interceptor = AuthTokenInterceptor(session: session)
        let refresh = AuthRefreshService(client: URLSessionHTTPClient(interceptors: []), session: session)
        self.refreshService = refresh

        self.httpClient = URLSessionHTTPClient(
            interceptors: [interceptor],
            refreshService: refresh
        )

        let auth = AuthService(client: httpClient, sessionService: session)
        self.authService = auth

        let profile = ProfileService(client: httpClient)
        self.profileService = profile

        self.foodService = FoodService(client: httpClient)
        self.userService = UserService(client: httpClient)
        self.waterTrackingService = WaterTrackingService(client: httpClient)
        self.dailySummaryService = DailySummaryService(client: httpClient)
        self.goalsService = GoalsService(client: httpClient)
        self.analyticsService = AnalyticsService(client: httpClient)
        
        self.activityService = ActivityService(client: httpClient)
        self.workoutService = WorkoutService(client: httpClient)
        self.sleepService = SleepService(client: httpClient)
        
        self.sessionBootstrapService = SessionBootstrapService(
            profileService: profile,
            sessionService: session
        )

        self.googleSignInService = GoogleSignInService()
        
        self.activityHealthKitService = ActivityHealthKitService()
        self.workoutHealthKitService = WorkoutHealthKitService()
        self.sleepHealthKitService = SleepHealthKitService()
        
        self.activitySync = ActivitySyncCoordinator(
            healthKitService: activityHealthKitService,
            activityService: activityService
        )

        #if DEBUG
        AnalyticsManager.shared.setMode(.debug)
        #else
        AnalyticsManager.shared.setMode(.live)
        #endif
        self.analyticsManager = AnalyticsManager.shared
    }
}
