import SwiftUI
import Observation

@Observable
@MainActor
final class AppCoordinator {
    var route: AppRoute = .loading
    private let container: AppDependency

    init(container: AppDependency) {
        self.container = container
    }

    @ViewBuilder
    func startView() -> some View {
        switch route {
        case .loading:
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background)
                .ignoresSafeArea()

        case .auth:
            AuthFactory.make(container: container, coordinator: self)

        case .profileForm:
            ProfileFormFactory.make(container: container, coordinator: self)

        case .main:
            MainTabFactory.make(container: container, coordinator: self)
        }
    }

    func bootstrap() async {
        let result = await container.sessionBootstrapService.restoreSession()

        switch result {
        case .auth:
            route = .auth
        case .profileForm:
            route = .profileForm
        case .main:
            route = .main
        }
    }

    func goToAuth() { route = .auth }
    func goToProfileForm() { route = .profileForm }
    func goToMain() { route = .main }
}

