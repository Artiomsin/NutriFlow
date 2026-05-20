
import SwiftUI

struct FoodSection: View {

    @ObservedObject var viewModel: FoodViewModel

    var onAddFood: (() -> Void)?

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

        switch viewModel.state {

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
                            Task {
                                await viewModel.deleteFood(id: entry.id)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.deleteFood(id: entry.id)
                                    
                                }
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

            ErrorMessageView(
                text: error.localizedDescription
            )
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
