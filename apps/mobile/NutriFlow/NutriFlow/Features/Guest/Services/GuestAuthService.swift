import Foundation

final class GuestAuthService: AuthServiceProtocol {
    private let store: GuestStore
    private let innerAuth: AuthService
    private let httpClient: HTTPClient
    private let cacheService: CacheService

    init(store: GuestStore, httpClient: HTTPClient, sessionService: AuthSessionService, cacheService: CacheService) {
        self.store = store
        self.httpClient = httpClient
        self.innerAuth = AuthService(client: httpClient, sessionService: sessionService)
        self.cacheService = cacheService
    }

    func register(email: String, password: String, firstName: String, lastName: String) async throws {
        try await innerAuth.register(email: email, password: password, firstName: firstName, lastName: lastName)
        do {
            try await store.migrateToBackend(
                foodService: FoodService(client: httpClient),
                waterService: WaterTrackingService(client: httpClient)
            )
            await cacheService.clear()
        } catch {
            print("[GuestAuthService] register migration error: \(error)")
            throw GuestError.migrationFailed(error.localizedDescription)
        }
    }

    func login(email: String, password: String) async throws {
        try await innerAuth.login(email: email, password: password)
        do {
            try await store.migrateToBackend(
                foodService: FoodService(client: httpClient),
                waterService: WaterTrackingService(client: httpClient)
            )
            await cacheService.clear()
        } catch {
            print("[GuestAuthService] login migration error: \(error)")
            throw GuestError.migrationFailed(error.localizedDescription)
        }
    }

    func signInWithGoogle(idToken: String) async throws {
        try await innerAuth.signInWithGoogle(idToken: idToken)
        do {
            try await store.migrateToBackend(
                foodService: FoodService(client: httpClient),
                waterService: WaterTrackingService(client: httpClient)
            )
            await cacheService.clear()
        } catch {
            print("[GuestAuthService] google sign-in migration error: \(error)")
            throw GuestError.migrationFailed(error.localizedDescription)
        }
    }

    func logout() async throws {
        try await innerAuth.logout()
        store.clear()
        await cacheService.clear()
    }

    func logoutAll() async throws {
        try await innerAuth.logoutAll()
        store.clear()
        await cacheService.clear()
    }
}
