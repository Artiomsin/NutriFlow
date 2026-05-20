import SwiftUI

struct FoodSection: View {

    @Bindable var foodViewModel: FoodViewModel
    var onAddFood: (() -> Void)?
    var onDeleteFood: ((String) -> Void)?

    var body: some View {

        VStack(alignment: .leading, spacing: 20) {

            HStack {

                Text("Today's Food")
                    .font(.title3.bold())
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Button {
                    onAddFood?()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.accent)
                    .cornerRadius(10)
                }
            }

            content
        }
    }

    @ViewBuilder
    private var content: some View {

        switch foodViewModel.state {

        case .idle, .loading:

            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity)

        case .loaded(let entries):

            if entries.isEmpty {

                emptyState

            } else {

                LazyVStack(spacing: 14) {

                    ForEach(sortedEntries(entries)) { entry in

                        FoodCard(entry: entry) {
                            onDeleteFood?(entry.id)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                onDeleteFood?(entry.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

        case .saving:

            ProgressView()
                .tint(.white)

        case .error(let error):

            ErrorMessageView(text: error.localizedDescription)
        }
    }

    private func sortedEntries(_ entries: [FoodEntry]) -> [FoodEntry] {
        entries.sorted { $0.createdAt > $1.createdAt }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 42))
                .foregroundColor(AppTheme.textSecondary)

            Text("No food added today")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
}

#Preview {
    FoodSectionPreview()
}

struct FoodSectionPreview: View {
    var body: some View {
        let session = SessionManager(tokenStorage: TokenStorage(keychain: KeychainService()))

        let foodVM = FoodViewModel(
            session: session,
            service: MockFoodService()
        )
        foodVM.setPreviewState(.loaded([
            FoodEntry(id: "1", userId: "1", name: "Chicken breast", calories: 165, protein: 31, fat: 4, carbs: 0, createdAt: "2026-05-18T10:00:00Z", updatedAt: nil),
            FoodEntry(id: "2", userId: "1", name: "Rice", calories: 200, protein: 4, fat: 1, carbs: 45, createdAt: "2026-05-18T12:00:00Z", updatedAt: nil),
            FoodEntry(id: "3", userId: "1", name: "Salad", calories: 85, protein: 2, fat: 5, carbs: 8, createdAt: "2026-05-18T14:00:00Z", updatedAt: nil)
        ]))

        return FoodSection(
            foodViewModel: foodVM,
            onAddFood: {},
            onDeleteFood: { _ in }
        )
        .padding()
        .background(AppTheme.background)
        .preferredColorScheme(.dark)
    }
}
