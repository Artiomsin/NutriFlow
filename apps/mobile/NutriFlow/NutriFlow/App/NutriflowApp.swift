import SwiftUI
import GoogleSignIn

@main
struct NutriflowApp: App {

    private let container = AppDependencyContainer()
    private let coordinator: AppCoordinator
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasRecordedActive = false

    init() {
        self.coordinator = AppCoordinator(container: container)

        print("NutriflowApp создан")
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                AppColors.background.ignoresSafeArea()

                coordinator.startView()
                    .id(coordinator.route)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.35), value: coordinator.route)
            }
           
            .environment(container.themeStore)
            .preferredColorScheme(
                            container.themeStore.mode.colorScheme
                        )
            
            .task {
                container.analyticsTracker.track(.appLaunched)
                await coordinator.bootstrap()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    if hasRecordedActive {
                        container.analyticsTracker.track(.appForeground)
                    } else {
                        hasRecordedActive = true
                    }
                case .background:
                    container.analyticsTracker.track(.appBackground)
                default:
                    break
                }
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
