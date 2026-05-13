import SwiftUI

struct ProfileDisplayView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @EnvironmentObject var session: SessionManager
    var onLogout: (() -> Void)?
    
    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.04, blue: 0.06)
                .ignoresSafeArea()
            ScrollView(showsIndicators: false) {

                VStack(spacing: 24) {

                    if case .loaded(let profile) = viewModel.state {

                        VStack(spacing: 16) {

                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.green)

                            VStack(spacing: 12) {

                                VStack(spacing: 4) {

                                    if let firstName = profile.firstName,
                                       let lastName = profile.lastName {

                                        Text("\(firstName) \(lastName)")
                                            .font(.title2.bold())
                                            .foregroundColor(.white)
                                    }

                                    if let email = profile.email {

                                        Text(email)
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }

                                NavigationLink {

                                    EditProfileView(viewModel: viewModel)

                                } label: {

                                    HStack(spacing: 6) {

                                        Image(systemName: "pencil")

                                        Text("Edit profile")
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.green)
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.top, 40)

                        VStack(spacing: 16) {

                            ProfileInfoCard(
                                icon: "scalemass",
                                title: "Weight",
                                value: profile.weight.map { "\($0) kg" } ?? "Not set"
                            )

                            ProfileInfoCard(
                                icon: "ruler",
                                title: "Height",
                                value: profile.height.map { "\($0) cm" } ?? "Not set"
                            )

                            ProfileInfoCard(
                                icon: "calendar",
                                title: "Age",
                                value: profile.age.map { "\($0) years" } ?? "Not set"
                            )

                            ProfileInfoCard(
                                icon: "target",
                                title: "Goal",
                                value: profile.goal?.displayName ?? "Not set"
                            )

                            ProfileInfoCard(
                                icon: "figure.walk",
                                title: "Activity",
                                value: profile.activityLevel?.displayName ?? "Not set"
                            )
                        }

                    } else if case .loading = viewModel.state {

                        ProgressView()
                            .tint(.white)

                    } else if case .empty = viewModel.state {

                        VStack(spacing: 16) {

                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.green)

                            Text("No profile data. Please create your profile.")
                                .foregroundColor(.white.opacity(0.6))
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
                            .foregroundColor(.red.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
            
        }
    }
}



#Preview {

    let session = SessionManager(
        tokenStorage: TokenStorage(
            keychain: KeychainService()
        )
    )

    let vm = ProfileViewModel(
        session: session,
        service: MockProfileService()
    )

    vm.setPreviewState(
        .loaded(
            UserProfile(
                id: UUID().uuidString,
                userId: UUID().uuidString,
                email: "artem@example.com",
                firstName: "Artem",
                lastName: "Developer",
                weight: 82,
                height: 183,
                age: 24,
                goal: .gain,
                activityLevel: .high,
                createdAt: "2026-05-13",
                updatedAt: "2026-05-13"
            )
        )
    )

    return NavigationStack {
        ProfileDisplayView(viewModel: vm)
            .environmentObject(session)
    }
}


final class MockProfileService: ProfileServiceProtocol {
    func deleteMyProfile(token: String) async throws -> EmptyResponse {
        fatalError()
    }
    

    func getMyProfile(token: String) async throws -> UserProfile {
        fatalError()
    }

    func createProfile(
        token: String,
        weight: Double?,
        height: Int?,
        age: Int?,
        goal: Goal?,
        activityLevel: ActivityLevel?
    ) async throws -> UserProfile {
        fatalError()
    }

    func updateMyProfile(
        token: String,
        weight: Double?,
        height: Int?,
        age: Int?,
        goal: Goal?,
        activityLevel: ActivityLevel?
    ) async throws -> UserProfile {
        fatalError()
    }

    
}
