import Foundation

final class GuestDependencyContainer: AppDependency {
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

    deinit {
        print("[GuestDependencyContainer] УНИЧТОЖЕН (выход из гостевого режима)")
    }

    init(store: GuestStore) {
        self.cacheService = CacheService()
        let keychain = KeychainService()
        let storage = KeychainTokenStorage(keychain: keychain)
        self.tokenStorage = storage
        let session = AuthSessionService(tokenStorage: storage)
        self.sessionService = session

        let interceptor = AuthTokenInterceptor(session: session)
        self.httpClient = URLSessionHTTPClient(interceptors: [interceptor])

        self.refreshService = AuthRefreshService(client: URLSessionHTTPClient(interceptors: []), session: session)
        self.sessionBootstrapService = SessionBootstrapService(
            profileService: StubProfileService(),
            sessionService: session
        )

        self.authService = GuestAuthService(store: store, httpClient: httpClient, sessionService: session, cacheService: cacheService)
        self.profileService = StubProfileService()
        self.userService = StubUserService()

        let dailySummary = GuestDailySummaryService(store: store)
        self.dailySummaryService = dailySummary
        self.foodService = GuestFoodService(store: store)
        self.waterTrackingService = GuestWaterService(store: store)
        self.goalsService = GuestGoalsService()
        self.analyticsService = GuestAnalyticsService(summaryService: dailySummary, store: store)
        self.googleSignInService = GoogleSignInService()
        self.analyticsManager = .shared
    }
}
