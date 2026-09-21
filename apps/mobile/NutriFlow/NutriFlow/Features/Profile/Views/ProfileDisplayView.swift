import SwiftUI

struct ProfileDisplayView: View {
    @Bindable var viewModel: ProfileViewModel
    let onEdit: () -> Void

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if case .loaded = viewModel.state {
                        VStack(spacing: 16) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: AppSpacing.avatarSize))
                                .foregroundColor(AppColors.accent)

                            VStack(spacing: 12) {
                                VStack(spacing: 4) {
                                    Text("\(viewModel.firstName) \(viewModel.lastName)")
                                        .font(.title2.bold())
                                        .foregroundColor(AppColors.textPrimary)

                                    Text(viewModel.email)
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.textSecondary)
                                }

                                Button {
                                    onEdit()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "pencil")
                                        Text("Edit profile")
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(AppColors.accentOnPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(AppColors.accent)
                                    .cornerRadius(AppRadius.small)
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
                                .font(.system(size: AppSpacing.avatarSize))
                                .foregroundColor(AppColors.accent)
                            Text("No profile data. Please create your profile.")
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    } else if case .error(let error) = viewModel.state {
                        ErrorMessageView(text: error.localizedDescription)
                    }
                }
                .padding(.horizontal, AppSpacing.paddingHorizontal)
                .padding(.bottom, AppSpacing.bottomPadding)
                .frame(minHeight: geo.size.height - AppSpacing.bottomPadding)
                }
                .scrollContentBackground(.hidden)
                .background(AppColors.background)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.trackScreen("profile") }
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
    
}
