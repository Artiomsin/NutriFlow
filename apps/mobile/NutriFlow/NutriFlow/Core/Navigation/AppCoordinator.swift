import SwiftUI
import Observation

@Observable
@MainActor
final class AppCoordinator {
    var route: AppRoute = .splash
    private let container: AppDependency
    private(set) var isGuest: Bool = false
    private var guestContainer: GuestDependencyContainer?

    init(container: AppDependency) {
        self.container = container
        NotificationCenter.default.addObserver(
            forName: .sessionExpired,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isGuest else { return }
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
            AuthFactory.make(container: activeContainer, coordinator: self)

        case .profileForm:
            ProfileFormFactory.make(container: activeContainer, coordinator: self)

        case .main:
            MainTabFactory.make(container: activeContainer, coordinator: self, isGuest: isGuest)
        }
    }

    func bootstrap() async {
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        if !UserDefaults.standard.bool(forKey: "onboardingShown") {
            route = .onboarding
            return
        }

        if UserDefaults.standard.bool(forKey: "isGuest") {
            print("[Coordinator] bootstrap: isGuest=true — вхожу как гость")
            enterGuestMode()
            route = .main
            return
        }

        let result = await container.sessionBootstrapService.restoreSession()
        route = switch result {
        case .auth: .auth
        case .profileForm: .profileForm
        case .main: .main
        }
    }

    func continueAsGuest() {
        print("[Coordinator] continueAsGuest — включаю гостевой режим")
        UserDefaults.standard.set(true, forKey: "isGuest")
        enterGuestMode()
        route = .main
    }

    func goToAuth() {
        print("[Coordinator] goToAuth\(isGuest ? " (гость)" : "")")
        route = .auth
    }

    func goToProfileForm() {
        checkGuestTransition()
        route = .profileForm
    }

    func goToMain() {
        checkGuestTransition()
        route = .main
    }


    private func enterGuestMode() {
        isGuest = true
        guestContainer = GuestDependencyContainer(store: .shared)
    }

    private var activeContainer: AppDependency {
        guestContainer ?? container
    }

    private func checkGuestTransition() {
        guard isGuest, container.tokenStorage.getAccessToken() != nil else { return }
        isGuest = false
        guestContainer = nil
        UserDefaults.standard.removeObject(forKey: "isGuest")
    }
    
    deinit {
            #if DEBUG
            print("AppCoordinator УНИЧТОЖЕН!")
            #endif
        }
}
