import SwiftUI

struct ProfileDisplayView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @EnvironmentObject var session: SessionManager
    var onLogout: (() -> Void)?
    @State private var showEditProfile = false

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
                                    showEditProfile = true
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
                                value: viewModel.weight.isEmpty ? "Not set" : "\(viewModel.weight) kg"
                            )
                            ProfileInfoCard(
                                icon: "ruler",
                                title: "Height",
                                value: viewModel.height.isEmpty ? "Not set" : "\(viewModel.height) cm"
                            )
                            ProfileInfoCard(
                                icon: "calendar",
                                title: "Age",
                                value: viewModel.age.isEmpty ? "Not set" : "\(viewModel.age) years"
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

                    Button {
                        onLogout?()
                    } label: {
                        Text("Logout")
                            .font(.headline)
                            .foregroundColor(AppTheme.logoutBorder)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                                    .stroke(AppTheme.logoutBorder, lineWidth: 1)
                                    .background(AppTheme.logoutBackground)
                            )
                            .cornerRadius(AppTheme.cornerRadiusMedium)
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, AppTheme.paddingHorizontal)
                .padding(.bottom, AppTheme.bottomPadding)
                .frame(minHeight: UIScreen.main.bounds.height - AppTheme.bottomPadding)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
        }
        .fullScreenCover(isPresented: $showEditProfile) {
            EditProfileView(viewModel: viewModel) {
                showEditProfile = false
            }
        }
    }
}


#Preview {
    let session = SessionManager(tokenStorage: TokenStorage(keychain: KeychainService()))
    let vm = ProfileViewModel(
        session: session,
        profileService: MockProfileService(),
        userService: MockUserService()
    )

    ProfileDisplayViewPreviewWrapper(vm: vm, session: session)
        .environmentObject(session)
        .preferredColorScheme(.dark)
}

struct ProfileDisplayViewPreviewWrapper: View {
    @ObservedObject var vm: ProfileViewModel
    let session: SessionManager

    var body: some View {
        ProfileDisplayView(viewModel: vm)
            .onAppear {
                vm.email = "test@example.com"
                vm.firstName = "Artem"
                vm.lastName = "Developer"
                vm.weight = "82"
                vm.height = "183"
                vm.age = "24"
                vm.goal = .gain
                vm.activityLevel = .high
                vm.setPreviewState(.loaded(UserProfile(
                    id: UUID().uuidString,
                    userId: UUID().uuidString,
                    email: "test@example.com",
                    firstName: "Artem",
                    lastName: "Developer",
                    weight: 82,
                    height: 183,
                    age: 24,
                    goal: .gain,
                    activityLevel: .high,
                    createdAt: nil,
                    updatedAt: nil
                )))
            }
    }
}


final class MockUserService: UserServiceProtocol {
    func createUser(email: String, password: String, firstName: String?, lastName: String?) async throws -> User {
        User(id: UUID().uuidString, email: email, firstName: firstName ?? "", lastName: lastName ?? "")
    }
    func getUsers(token: String) async throws -> [User] { [] }
    func getMe(token: String) async throws -> User {
        User(id: UUID().uuidString, email: "test@example.com", firstName: "Artem", lastName: "Developer")
    }
    func updateMe(token: String, email: String?, password: String?, firstName: String?, lastName: String?) async throws -> User {
        User(id: UUID().uuidString, email: email ?? "", firstName: firstName ?? "", lastName: lastName ?? "")
    }
}

final class MockProfileService: ProfileServiceProtocol {
    func getMyProfile(token: String) async throws -> UserProfile {
        UserProfile(id: UUID().uuidString, userId: UUID().uuidString, email: "test@example.com", firstName: "Artem", lastName: "Developer", weight: 82, height: 183, age: 24, goal: .gain, activityLevel: .high, createdAt: nil, updatedAt: nil)
    }
    func createProfile(token: String, weight: Double?, height: Int?, age: Int?, goal: Goal?, activityLevel: ActivityLevel?) async throws -> UserProfile {
        UserProfile(id: UUID().uuidString, userId: UUID().uuidString, email: nil, firstName: nil, lastName: nil, weight: weight, height: height, age: age, goal: goal, activityLevel: activityLevel, createdAt: nil, updatedAt: nil)
    }
    func updateMyProfile(token: String, weight: Double?, height: Int?, age: Int?, goal: Goal?, activityLevel: ActivityLevel?) async throws -> UserProfile {
        UserProfile(id: UUID().uuidString, userId: UUID().uuidString, email: nil, firstName: nil, lastName: nil, weight: weight, height: height, age: age, goal: goal, activityLevel: activityLevel, createdAt: nil, updatedAt: nil)
    }
    func deleteMyProfile(token: String) async throws -> EmptyResponse {
        EmptyResponse()
    }
}
