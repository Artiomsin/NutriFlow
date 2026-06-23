import Foundation

final class GuestAuthService: AuthServiceProtocol {
    private let store: GuestStore
    private let innerAuth: AuthService
    private let httpClient: HTTPClient

    init(store: GuestStore, httpClient: HTTPClient, sessionService: AuthSessionService) {
        self.store = store
        self.httpClient = httpClient
        self.innerAuth = AuthService(client: httpClient, sessionService: sessionService)
    }

    func register(email: String, password: String, firstName: String, lastName: String) async throws {
        try await innerAuth.register(email: email, password: password, firstName: firstName, lastName: lastName)
        do {
            try await store.migrateToBackend(
                foodService: FoodService(client: httpClient),
                waterService: WaterTrackingService(client: httpClient)
            )
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
        } catch {
            print("[GuestAuthService] login migration error: \(error)")
            throw GuestError.migrationFailed(error.localizedDescription)
        }
    }

    func logout() async throws {
        try await innerAuth.logout()
        store.clear()
    }

    func logoutAll() async throws {
        try await innerAuth.logoutAll()
        store.clear()
    }
}
