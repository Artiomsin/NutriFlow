import SwiftUI
import Observation

@Observable
@MainActor
final class AppCoordinator {
    var route: AppRoute = .splash
    var pendingNotificationType: AppNotificationType?
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

        let result: SessionBootstrapResult
        do {
            result = try await container.sessionBootstrapService.restoreSession()
        } catch {
            #if DEBUG
            print("[Session] Failed to restore the session: \(error)")
            #endif
            route = .auth
            return
        }

        route = switch result {
        case .auth: .auth
        case .profileForm: .profileForm
        case .main: .main
        }

        if case .auth = route {
            clearLocalSessionState()
        }

        if case .main = route {
            container.activitySync.start()
        }
    }

    func goToAuth() {
        print("[Coordinator] goToAuth")
        clearLocalSessionState()
        route = .auth
    }

    func goToProfileForm() {
        route = .profileForm
    }

    func goToMain() {
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
        Task { await container.cacheService.clear() }
    }

    deinit {
            #if DEBUG
            print("AppCoordinator УНИЧТОЖЕН!")
            #endif
        }
}
