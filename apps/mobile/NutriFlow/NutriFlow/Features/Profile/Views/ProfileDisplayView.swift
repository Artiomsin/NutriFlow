import SwiftUI

struct ProfileDisplayView: View {
    @Bindable var viewModel: ProfileViewModel
    let onEdit: () -> Void

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if case .loaded = viewModel.state {
                        VStack(spacing: 16) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: AppTheme.avatarSize))
                                .foregroundColor(AppTheme.accent)

                            VStack(spacing: 12) {
                                VStack(spacing: 4) {
                                    Text("\(viewModel.firstName) \(viewModel.lastName)")
                                        .font(.title2.bold())
                                        .foregroundColor(AppTheme.textPrimary)

                                    Text(viewModel.email)
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.textSecondary)
                                }

                                Button {
                                    onEdit()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "pencil")
                                        Text("Edit profile")
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(AppTheme.primaryButtonText)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.accent)
                                    .cornerRadius(AppTheme.cornerRadiusSmall)
                                }
                            }
                        }
                        .padding(.top, 40)

                        VStack(spacing: 16) {
                            ProfileInfoCard(
                                icon: "scalemass",
                                title: "Weight",
                                value: viewModel.weight.isEmpty ? "Not set" : "\(viewModel.weight) \(UnitConversion.bodyWeightUnitLabel(preferred: viewModel.preferredUnits))"
                            )
                            ProfileInfoCard(
                                icon: "ruler",
                                title: "Height",
                                value: viewModel.height.isEmpty ? "Not set" : "\(viewModel.height) \(UnitConversion.heightUnitLabel(preferred: viewModel.preferredUnits))"
                            )
                            ProfileInfoCard(
                                icon: "calendar",
                                title: "Age",
                                value: viewModel.age.isEmpty ? "Not set" : "\(viewModel.age) years"
                            )
                            ProfileInfoCard(
                                icon: "figure.stand",
                                title: "Gender",
                                value: viewModel.gender?.displayName ?? "Not set"
                            )
                            ProfileInfoCard(
                                icon: "target",
                                title: "Goal",
                                value: viewModel.goal?.displayName ?? "Not set"
                            )
                            ProfileInfoCard(
                                icon: "figure.walk",
                                title: "Activity",
                                value: viewModel.activityLevel?.displayName ?? "Not set"
                            )
                        }
                    } else if case .loading = viewModel.state {
                        ProgressView()
                            .tint(.white)
                    } else if case .empty = viewModel.state {
                        VStack(spacing: 16) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: AppTheme.avatarSize))
                                .foregroundColor(AppTheme.accent)
                            Text("No profile data. Please create your profile.")
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    } else if case .error(let error) = viewModel.state {
                        ErrorMessageView(text: error.localizedDescription)
                    }
                }
                .padding(.horizontal, AppTheme.paddingHorizontal)
                .padding(.bottom, AppTheme.bottomPadding)
                .frame(minHeight: UIScreen.main.bounds.height - AppTheme.bottomPadding)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { AnalyticsManager.shared.track(.screenView(screen: "profile")) }
    }
}

#Preview("Profile Display") {
    let container = AppDependencyContainer()
    let coordinator = AppCoordinator(container: container)
    let viewModel = ProfileViewModel(
        coordinator: coordinator,
        authService: MockAuthService(),
        profileService: MockProfileService(),
        userService: MockUserService()
    )
    NavigationStack {
        ProfileDisplayView(viewModel: viewModel, onEdit: {})
            .task { await viewModel.loadData() }
    }
    .preferredColorScheme(.dark)
}
