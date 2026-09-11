import SwiftUI

enum SettingsNavRoute: Hashable {
    case profile
    case editProfile
}

struct SettingsView: View {
    @Bindable var viewModel: ProfileViewModel
    let coordinator: AppCoordinator?
    var tabBarState: TabBarState = TabBarState()
    @State private var navPath: [SettingsNavRoute] = []

    var body: some View {
        let _ = print("SettingsView body")
        NavigationStack(path: $navPath) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    header
                        .padding(.top, 30)

                    LazyVStack(spacing: 24) {
                        accountSection
                        unitsSection
                    }
                    .padding(.horizontal, AppTheme.paddingHorizontal)
                }
                .padding(.bottom, 100)
            }
            .minimizeTabBarOnScroll(
                tabBarState: tabBarState,
                isActive: { navPath.isEmpty }
            )
            .background(AppTheme.background)
            .refreshable { await viewModel.loadData() }
            .task {
                AnalyticsManager.shared.track(.screenView(screen: "settings"))
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
                }
            }
        }
        .tint(AppTheme.accent)
        .onChange(of: navPath) { _, newPath in
            tabBarState.isTabBarHidden = !newPath.isEmpty
        }
    }

    private var header: some View {
        Text("Settings")
            .font(Font.h1)
            .foregroundColor(AppTheme.textPrimary)
            .frame(maxWidth: .infinity)
    }


    private var accountSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Account")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppTheme.textTertiary)
                Spacer()
            }
            .padding(.leading, 2)

            SettingsRow(icon: "person", title: "Profile")
                .onTapGesture { navPath.append(.profile) }

            SettingsRow(icon: "arrow.right.square", title: "Log Out", tint: .red)
                .onTapGesture { Task { await viewModel.logout() } }
        }
    }


    private var unitsSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Units")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppTheme.textTertiary)
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
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
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
                .font(.system(size: AppTheme.iconSize))
                .foregroundColor(AppTheme.accent)
                .frame(width: 30)

            Text(title)
                .font(.system(size: 15))
                .foregroundColor(AppTheme.textPrimary)

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
                            .foregroundColor(active ? AppTheme.primaryButtonText : AppTheme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(active ? AppTheme.accent : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .padding(2)
            .background(AppTheme.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, AppTheme.paddingHorizontal)
        .padding(.vertical, 12)
    }
}

extension SettingsView: Equatable {
    static func == (lhs: SettingsView, rhs: SettingsView) -> Bool {
        lhs.tabBarState === rhs.tabBarState
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
    SettingsView(viewModel: viewModel, coordinator: coordinator)
        .preferredColorScheme(.dark)
}
