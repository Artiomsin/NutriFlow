import SwiftUI
import UIKit

enum SettingsNavRoute: Hashable {
    case profile
    case editProfile
    case goals
}

struct SettingsView: View {
    @Bindable var viewModel: ProfileViewModel
    let goalsVM: GoalsViewModel
    let coordinator: AppCoordinator?
    var tabBarState: TabBarState = TabBarState()
    let isActive: Bool
    let weightReminderScheduler: WeightReminderScheduling
    let waterReminderScheduler: WaterReminderScheduling
    let achievementNotificationService: AchievementNotificationService
    @State private var isNotificationPermissionDenied = false
    @State private var navPath: [SettingsNavRoute] = []
    @State private var hasLoadedSettings = false
    @Environment(ThemeStore.self)
    private var themeStore

    init(viewModel: ProfileViewModel, goalsVM: GoalsViewModel, coordinator: AppCoordinator?, weightReminderScheduler: WeightReminderScheduling, waterReminderScheduler: WaterReminderScheduling, achievementNotificationService: AchievementNotificationService, tabBarState: TabBarState = TabBarState(), isActive: Bool = true) {
        self.viewModel = viewModel
        self.goalsVM = goalsVM
        self.coordinator = coordinator
        self.weightReminderScheduler = weightReminderScheduler
        self.waterReminderScheduler = waterReminderScheduler
        self.achievementNotificationService = achievementNotificationService
        self.tabBarState = tabBarState
        self.isActive = isActive
    }

    var body: some View {
        let _ = print("SettingsView body")
        NavigationStack(path: $navPath) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    header
                        .padding(.top, 30)

                    LazyVStack(spacing: 24) {
                        accountSection
                        goalsSection
                        unitsSection
                        notificationsSection
                        appearanceSection
                    }
                    .padding(.horizontal, AppSpacing.paddingHorizontal)
                }
                .padding(.bottom, 100)
            }
            .minimizeTabBarOnScroll(
                tabBarState: tabBarState,
                isActive: { navPath.isEmpty }
            )
            .background(AppColors.background)
            .refreshable {
                let task = Task { await viewModel.loadData() }
                await task.value
            }
            .task(id: isActive) {
                guard isActive, !hasLoadedSettings else { return }
                hasLoadedSettings = true
                await viewModel.loadData()
            }
            .navigationDestination(for: SettingsNavRoute.self) { route in
                switch route {
                case .profile:
                    ProfileDisplayView(viewModel: viewModel) {
                        navPath.append(.editProfile)
                    }
                case .editProfile:
                    EditProfileView(viewModel: viewModel)
                case .goals:
                    GoalsManagementView(goalsVM: goalsVM)
                }
            }
        }
        .tint(AppColors.accent)
        .alert("Notifications are disabled", isPresented: $isNotificationPermissionDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow notifications for NutriFlow in iPhone Settings to receive reminders.")
        }
        .onChange(of: navPath) { _, newPath in
            tabBarState.isTabBarHidden = !newPath.isEmpty
        }
    }

    private var header: some View {
        Text("Settings")
            .font(AppTypography.heading1)
            .foregroundColor(AppColors.textPrimary)
            .frame(maxWidth: .infinity)
    }


    private var accountSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Account")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppColors.textTertiary )
                Spacer()
            }
            .padding(.leading, 2)

            SettingsRow(icon: "person", title: "Profile")
                .onTapGesture { navPath.append(.profile) }

            SettingsRow(icon: "arrow.right.square", title: "Log Out", tint: .red)
                .onTapGesture { Task { await viewModel.logout() } }
        }
    }


    private var goalsSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Goals")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppColors.textTertiary )
                Spacer()
            }
            .padding(.leading, 2)

            SettingsRow(icon: "target", title: "Manage Your Goals")
                .onTapGesture { navPath.append(.goals) }
        }
    }

    private var notificationsSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Reminders")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AppColors.textTertiary)
                Spacer()
            }
            .padding(.leading, 2)

            Toggle("Weight reminder", isOn: Binding(
                get: { weightReminderScheduler.isWeightReminderEnabled },
                set: { isEnabled in
                    Task { await setWeightRemindersEnabled(isEnabled) }
                }
            ))
            .tint(AppColors.accent)
            .padding(.horizontal, AppSpacing.paddingHorizontal)
            .padding(.vertical, 14)
            .appGlassSurface()

            Toggle("Achievement notifications", isOn: Binding(
                get: { achievementNotificationService.isAchievementNotificationsEnabled },
                set: { isEnabled in
                    Task { await setAchievementNotificationsEnabled(isEnabled) }
                }
            ))
            .tint(AppColors.accent)
            .padding(.horizontal, AppSpacing.paddingHorizontal)
            .padding(.vertical, 14)
            .appGlassSurface()

            VStack(spacing: 0) {
                Toggle("Water reminder", isOn: Binding(
                    get: { waterReminderScheduler.isWaterReminderEnabled },
                    set: { isEnabled in
                        Task { await setWaterRemindersEnabled(isEnabled) }
                    }
                ))
                .tint(AppColors.accent)

                Divider()
                    .padding(.vertical, 12)

                DatePicker(
                    "Reminder time",
                    selection: waterReminderDate,
                    displayedComponents: .hourAndMinute
                )
                .disabled(!waterReminderScheduler.isWaterReminderEnabled)
            }
            .padding(.horizontal, AppSpacing.paddingHorizontal)
            .padding(.vertical, 14)
            .appGlassSurface()

            #if DEBUG
            Button(role: .destructive) {
                achievementNotificationService.resetTestState()
            } label: {
                Label("Reset achievement test state", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, AppSpacing.paddingHorizontal)
            .padding(.vertical, 14)
            .appGlassSurface()
            #endif
        }
    }

    private var waterReminderDate: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: waterReminderScheduler.reminderTime.hour,
                    minute: waterReminderScheduler.reminderTime.minute,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                guard let hour = components.hour, let minute = components.minute else { return }

                Task {
                    await waterReminderScheduler.updateReminderTime(
                        ReminderTime(hour: hour, minute: minute)
                    )
                }
            }
        )
    }

    private func setWeightRemindersEnabled(_ isEnabled: Bool) async {
        guard await weightReminderScheduler.setRemindersEnabled(isEnabled) else {
            isNotificationPermissionDenied = true
            return
        }
    }

    private func setWaterRemindersEnabled(_ isEnabled: Bool) async {
        guard await waterReminderScheduler.setWaterRemindersEnabled(isEnabled) else {
            isNotificationPermissionDenied = true
            return
        }
    }

    private func setAchievementNotificationsEnabled(_ isEnabled: Bool) async {
        guard await achievementNotificationService.setAchievementNotificationsEnabled(isEnabled) else {
            isNotificationPermissionDenied = true
            return
        }
    }

    private var appearanceSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Appearance")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AppColors.textTertiary)

                Spacer()
            }
            .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(
                            .system(
                                size: AppSpacing.iconSize,
                                weight: .medium
                            )
                        )
                        .foregroundStyle(AppColors.accent)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Theme")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppColors.textPrimary)

                        Text(themeStore.mode.title)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()
                }

                Picker(
                    "Theme",
                    selection: Binding(
                        get: {
                            themeStore.mode
                        },
                        set: {
                            themeStore.mode = $0
                        }
                    )
                ) {
                    ForEach(ThemeMode.allCases) { mode in
                        Text(mode.title)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .tint(AppColors.accent)

                Divider()
                    .opacity(0.3)

                Toggle(
                    isOn: Binding(
                        get: {
                            themeStore.glassEffectsMode == GlassEffectsMode.subtle
                        },
                        set: { isEnabled in
                            themeStore.glassEffectsMode = isEnabled ? GlassEffectsMode.subtle : GlassEffectsMode.off
                        }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Glass Effects")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppColors.textPrimary)

                        Text("Use subtle glass on supported interface elements.")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .tint(AppColors.accent)
            }
            .padding(.horizontal, AppSpacing.paddingHorizontal)
            .padding(.vertical, 14)
            .appGlassSurface()
        }
    }
    
    private var unitsSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Units")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppColors.textTertiary )
                Spacer()
            }
            .padding(.leading, 2)

            VStack(spacing: 0) {
                unitRow(
                    icon: "scalemass",
                    title: "Weight",
                    selection: $viewModel.preferredUnits.weight,
                    options: PreferredUnits.WeightUnit.allCases,
                    label: { $0 == .metric ? "kg / g" : "lb / oz" }
                )

                Divider()
                    .padding(.leading, 52)
                    .opacity(0.3)

                unitRow(
                    icon: "drop",
                    title: "Volume",
                    selection: $viewModel.preferredUnits.volume,
                    options: PreferredUnits.VolumeUnit.allCases,
                    label: { $0 == .metric ? "L / ml" : "fl oz" }
                )

                Divider()
                    .padding(.leading, 52)
                    .opacity(0.3)

                unitRow(
                    icon: "bolt",
                    title: "Energy",
                    selection: $viewModel.preferredUnits.energy,
                    options: PreferredUnits.EnergyUnit.allCases,
                    label: { $0 == .kcal ? "kcal" : "kJ" }
                )
            }
            .appGlassSurface()
        }
    }

    @ViewBuilder
    private func unitRow<T: Hashable>(
        icon: String,
        title: String,
        selection: Binding<T>,
        options: [T],
        label: @escaping (T) -> String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: AppSpacing.iconSize))
                .foregroundColor(AppColors.accent)
                .frame(width: 30)

            Text(title)
                .font(.system(size: 15))
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            HStack(spacing: 2) {
                ForEach(options, id: \.self) { option in
                    let active = selection.wrappedValue == option
                    Button {
                        selection.wrappedValue = option
                        PreferencesStore.shared.preferredUnits = viewModel.preferredUnits
                        Task { await viewModel.updatePreferredUnits() }
                    } label: {
                        Text(label(option))
                            .font(.system(size: 12, weight: active ? .semibold : .regular))
                            .foregroundColor(active ? AppColors.accentOnPrimary : AppColors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(active ? AppColors.accent : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .padding(2)
            .background(AppColors.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, AppSpacing.paddingHorizontal)
        .padding(.vertical, 12)

        if let unitsError = viewModel.unitsError {
            ErrorView(
                error: unitsError,
                onRetry: { Task { await viewModel.updatePreferredUnits() } }
            )
            .padding(.horizontal, AppSpacing.paddingHorizontal)
        }
    }
}



#Preview("Settings") {
    let container = AppDependencyContainer()
    let coordinator = AppCoordinator(container: container)
    let viewModel = ProfileViewModel(
        coordinator: coordinator,
        authService: MockAuthService(),
        profileService: MockProfileService(),
        userService: MockUserService()
    )
    SettingsView(
        viewModel: viewModel,
        goalsVM: GoalsViewModel(coordinator: coordinator, service: MockGoalsService()),
        coordinator: coordinator,
        weightReminderScheduler: container.weightReminderScheduler,
        waterReminderScheduler: container.waterReminderScheduler,
        achievementNotificationService: container.achievementNotificationService
    )
    .environment(container.themeStore)
        
}
