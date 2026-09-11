import SwiftUI
import Observation

@Observable
@MainActor
final class AppCoordinator {
    var route: AppRoute = .splash
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
                self.container.activitySync.stop()
                await self.container.cacheService.clear()
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

        let result = await container.sessionBootstrapService.restoreSession()
        route = switch result {
        case .auth: .auth
        case .profileForm: .profileForm
        case .main: .main
        }

        if case .main = route {
            container.activitySync.start()
        }
    }

    func goToAuth() {
        print("[Coordinator] goToAuth")
        container.activitySync.stop()
        route = .auth
    }

    func goToProfileForm() {
        route = .profileForm
    }

    func goToMain() {
        container.activitySync.start()
        route = .main
    }

    deinit {
            #if DEBUG
            print("AppCoordinator УНИЧТОЖЕН!")
            #endif
        }
}
