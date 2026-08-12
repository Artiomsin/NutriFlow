import SwiftUI
import GoogleSignIn

@main
struct NutriflowApp: App {

    private let container = AppDependencyContainer()
    private let coordinator: AppCoordinator

    init() {
        self.coordinator = AppCoordinator(container: container)
        print("NutriflowApp создан")
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                coordinator.startView()
                    .id(coordinator.route)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.35), value: coordinator.route)
            }
            .preferredColorScheme(.dark)
            .task {
                await coordinator.bootstrap()
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}


