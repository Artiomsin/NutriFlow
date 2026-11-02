import SwiftUI
import Observation

@Observable
@MainActor
final class AppCoordinator {
    var route: AppRoute = .splash
    var pendingNotificationType: AppNotificationType?
    var bootstrapError: AppError?
    private let container: AppDependency

    init(container: AppDependency) {
        self.container = container
        NotificationCenter.default.addObserver(
            forName: .sessionExpired,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.bootstrapError = nil
                self.clearLocalSessionState()
                self.route = .auth
            }
        }
    }

    @ViewBuilder
    func startView() -> some View {
        switch route {
        case .splash:
            SplashView()

        case .onboarding:
            OnboardingView(onComplete: { [weak self] in
                self?.goToAuth()
            })

        case .auth:
            AuthFactory.make(container: container, coordinator: self)

        case .profileForm:
            ProfileFormFactory.make(container: container, coordinator: self)

        case .main:
            MainTabView(container: container, coordinator: self)
        }
    }

    func bootstrap() async {
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        if !UserDefaults.standard.bool(forKey: "onboardingShown") {
            route = .onboarding
            return
        }

        await resolveSessionRoute()
    }

    @discardableResult
    func resolveSessionRoute() async -> SessionBootstrapResult {
        let result: SessionBootstrapResult

        do {
            result = try await container.sessionBootstrapService.restoreSession()
        } catch {
            #if DEBUG
            print("[Session] Failed to restore the session: \(error)")
            #endif
            bootstrapError = nil
            clearLocalSessionState()
            route = .auth
            return .auth
        }

        switch result {
        case .auth, .profileForm:
            bootstrapError = nil
        case .main(let error):
            bootstrapError = error
        }

        route = switch result {
        case .auth: .auth
        case .profileForm: .profileForm
        case .main: .main
        }

        switch result {
        case .auth:
            clearLocalSessionState()
        case .profileForm:
            await activatePrivateImageSession()
        case .main:
            await activatePrivateImageSession()
            container.activitySync.start()
        }

        return result
    }

    func retrySessionBootstrap() async {
        await resolveSessionRoute()
    }

    func goToAuth() {
        print("[Coordinator] goToAuth")
        bootstrapError = nil
        clearLocalSessionState()
        route = .auth
    }

    func goToProfileForm() {
        bootstrapError = nil
        Task { await activatePrivateImageSession() }
        route = .profileForm
    }

    func goToMain() {
        bootstrapError = nil
        Task { await activatePrivateImageSession() }
        container.activitySync.start()
        route = .main
    }

    func handleNotification(_ type: AppNotificationType) {
        pendingNotificationType = type
    }

    func restorePendingNotification() {
        guard let type = NotificationDelegate.consumePendingNotificationType() else { return }
        handleNotification(type)
    }

    func consumePendingNotification() -> AppNotificationType? {
        defer { pendingNotificationType = nil }
        return pendingNotificationType
    }

    private func clearLocalSessionState() {
        container.weightReminderScheduler.cancel()
        container.waterReminderScheduler.cancel()
        container.achievementNotificationService.clearSessionState()
        container.notificationPreferences.reset()
        container.activitySync.stop()
        WorkoutViewModel.resetSessionSyncState()
        SleepSyncCoordinator.resetSessionSyncState()
        Task {
            await container.imageCacheService.endPrivateSession()
            await container.cacheService.clear()
        }
    }

    private func activatePrivateImageSession() async {
        do {
            guard let sessionID = try container.sessionService.sessionID() else {
                return
            }
            await container.imageCacheService.startPrivateSession(sessionId: sessionID)
        } catch {
            #if DEBUG
            print("[Session] Could not activate private image cache: \(error)")
            #endif
        }
    }

    deinit {
            #if DEBUG
            print("AppCoordinator deinit!")
            #endif
        }
}
