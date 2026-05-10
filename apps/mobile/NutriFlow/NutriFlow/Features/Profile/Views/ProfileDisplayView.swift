import SwiftUI

struct ProfileDisplayView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @EnvironmentObject var session: SessionManager
    
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
                            
                            VStack(spacing: 4) {
                                let firstName = profile.firstName ?? TokenStorage.shared.getFirstName()
                                let lastName = profile.lastName ?? TokenStorage.shared.getLastName()
                                let email = profile.email ?? TokenStorage.shared.getEmail()
                                
                                if let firstName = firstName, let lastName = lastName {
                                    Text("\(firstName) \(lastName)")
                                        .font(.title2.bold())
                                        .foregroundColor(.white)
                                }
                                
                                if let email = email {
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.6))
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
                        .padding(.horizontal, 20)
                        
                    } else if case .loading = viewModel.state {
                        ProgressView()
                            .tint(.white)
                    } else if case .empty = viewModel.state {
                        VStack(spacing: 16) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.green)
                            
                            let firstName = TokenStorage.shared.getFirstName()
                            let lastName = TokenStorage.shared.getLastName()
                            let email = TokenStorage.shared.getEmail()
                            
                            if let firstName = firstName, let lastName = lastName {
                                Text("\(firstName) \(lastName)")
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                            }
                            
                            if let email = email {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(.top, 40)
                        
                        Text("No profile data. Please create your profile.")
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    } else if case .error(let error) = viewModel.state {
                        ErrorMessageView(text: error.localizedDescription)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                
                Button {
                    session.logout()
                } label: {
                    Text("Logout")
                        .font(.headline)
                        .foregroundColor(.red.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
        }
    }
}

struct ProfileInfoCard: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.green)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
            
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}