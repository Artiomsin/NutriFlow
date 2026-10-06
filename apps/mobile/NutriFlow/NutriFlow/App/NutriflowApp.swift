import SwiftUI
import GoogleSignIn

@main
struct NutriflowApp: App {

    private let container = AppDependencyContainer()
    private let coordinator: AppCoordinator
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasRecordedActive = false

    init() {
        let coordinator = AppCoordinator(container: container)
        self.coordinator = coordinator

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
            .glassEffectsMode(container.themeStore.glassEffectsMode)
            .preferredColorScheme(
                            container.themeStore.mode.colorScheme
                        )
            
            .task {
                container.analyticsTracker.track(.appLaunched)
                await coordinator.bootstrap()
                coordinator.restorePendingNotification()

                guard coordinator.route == .main else { return }
                await container.weightReminderScheduler.ensureScheduledIfEnabled()
                await container.waterReminderScheduler.ensureScheduledIfEnabled()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    if hasRecordedActive {
                        container.analyticsTracker.track(.appForeground)
                    } else {
                        hasRecordedActive = true
                    }

                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        coordinator.restorePendingNotification()
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
