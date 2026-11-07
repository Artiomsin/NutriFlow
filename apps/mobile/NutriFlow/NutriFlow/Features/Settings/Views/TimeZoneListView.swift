import SwiftUI

struct TimeZoneListView: View {
    @Binding var selectedTimeZone: String
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var timeZones: [String] {
        let all = TimeZone.knownTimeZoneIdentifiers.sorted()
        if searchText.isEmpty {
            return all
        }
        return all.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Search city or region", text: $searchText)
                }

                Section("All Time Zones") {
                    ForEach(timeZones, id: \.self) { identifier in
                        Button {
                            selectedTimeZone = identifier
                            dismiss()
                        } label: {
                            HStack {
                                Text(identifier)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedTimeZone == identifier {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppColors.accent)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Time Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            onDismiss()
        }
    }
}

#Preview {
    TimeZoneListView(
        selectedTimeZone: .constant("Europe/Minsk"),
        onDismiss: {}
    )
}
