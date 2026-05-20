import SwiftUI

struct WaterCard: View {

    let entry: WaterEntry

    var onDelete: (() -> Void)?

    @State private var showDeleteAlert = false

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            HStack(alignment: .top) {

                VStack(alignment: .leading, spacing: 4) {

                    Text("\(entry.amountMl) ml")
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)

                    Text(formatDate(entry.createdAt))
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Text("Water")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppTheme.accent)
            }

            HStack {

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
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.5) {

            showDeleteAlert = true
        }
        .alert("Delete Water", isPresented: $showDeleteAlert) {

            Button("Cancel", role: .cancel) {}

            Button("Delete", role: .destructive) {

                onDelete?()
            }

        } message: {

            Text("Are you sure you want to delete this water entry?")
        }
    }

    private func formatDate(_ value: String) -> String {

        value.prefix(10).description
    }
}
