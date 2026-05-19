import SwiftUI

struct FoodCard: View {

    let entry: FoodEntry
    var onDelete: (() -> Void)?

    @State private var showDeleteAlert = false

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            HStack(alignment: .top) {

                VStack(alignment: .leading, spacing: 4) {

                    Text(entry.name)
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)

                    Text(formatDate(entry.createdAt))
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Text("\(entry.calories) kcal")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppTheme.accent)
            }

            HStack(spacing: 12) {

                MacroBadge(
                    title: "P",
                    value: entry.protein ?? 0
                )

                MacroBadge(
                    title: "F",
                    value: entry.fat ?? 0
                )

                MacroBadge(
                    title: "C",
                    value: entry.carbs ?? 0
                )

                Spacer()

                Button {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.error)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
        .onLongPressGesture(minimumDuration: 0.5) {
            showDeleteAlert = true
        }
        .alert("Delete Food", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Are you sure you want to delete \"\(entry.name)\"?")
        }
    }

    private func formatDate(_ value: String) -> String {
        value.prefix(10).description
    }
}

struct MacroBadge: View {

    let title: String
    let value: Int

    var body: some View {

        HStack(spacing: 4) {

            Text(title)
                .font(.caption.bold())
                .foregroundColor(AppTheme.accent)

            Text("\(value)g")
                .font(.caption)
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.background)
        .cornerRadius(8)
    }
}