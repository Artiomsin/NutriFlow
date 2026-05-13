import SwiftUI

struct ProfileFormView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Binding var isCompleted: Bool
    
    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.04, blue: 0.06)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Text("Create Profile")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 60)
                    
                    Text("Tell us about yourself")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                    
                    VStack(spacing: 16) {
                        AppTextField(
                            title: "Weight (kg)",
                            text: $viewModel.weight,
                            keyboardType: .decimalPad
                        )
                        
                        AppTextField(
                            title: "Height (cm)",
                            text: $viewModel.height,
                            keyboardType: .numberPad
                        )
                        
                        AppTextField(
                            title: "Age",
                            text: $viewModel.age,
                            keyboardType: .numberPad
                        )
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Goal")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                            
                            HStack(spacing: 12) {
                                ForEach(Goal.allCases, id: \.self) { goal in
                                    SelectableChip(
                                        title: goal.displayName,
                                        isSelected: viewModel.goal == goal
                                    ) {
                                        viewModel.goal = goal
                                    }
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Activity Level")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                            
                            HStack(spacing: 12) {
                                ForEach(ActivityLevel.allCases, id: \.self) { level in
                                    SelectableChip(
                                        title: level.displayName,
                                        isSelected: viewModel.activityLevel == level
                                    ) {
                                        viewModel.activityLevel = level
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    if case .error(let error) = viewModel.state {
                        ErrorMessageView(text: error.localizedDescription)
                            .padding(.horizontal, 20)
                    }
                    
                    PrimaryButton(title: "Save") {
                        Task {
                            await viewModel.createProfile()
                            await viewModel.loadProfile()
                            
                            switch viewModel.state {
                            case .loaded:
                                isCompleted = true
                            default:
                                break
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    if case .saving = viewModel.state {
                        ProgressView()
                            .tint(.white)
                    }
                    
                    Spacer()
                }
            }
        }
    }
}

struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color.green : Color.white.opacity(0.1))
                .cornerRadius(20)
        }
    }
}

extension Goal: CaseIterable {
    static var allCases: [Goal] {
        [.lose, .gain, .maintain]
    }
    
    var displayName: String {
        switch self {
        case .lose: return "Lose"
        case .gain: return "Gain"
        case .maintain: return "Maintain"
        }
    }
}

extension ActivityLevel: CaseIterable {
    static var allCases: [ActivityLevel] {
        [.low, .medium, .high]
    }
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}