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

    init() {
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
        
        self.sessionBootstrapService = SessionBootstrapService(
            profileService: profile,
            sessionService: session
        )
        
    }
}
