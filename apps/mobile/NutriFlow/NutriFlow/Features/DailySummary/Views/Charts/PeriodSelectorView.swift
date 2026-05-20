import SwiftUI

enum RangeField: String, CaseIterable {
    case from = "From"
    case to = "To"
}

struct PeriodSelectorView: View {
    let selectedPeriod: PeriodType
    let fromDate: Date
    let toDate: Date
    let onPeriodChange: (PeriodType) -> Void
    let onCustomRange: (Date, Date) -> Void
    @State private var showDatePicker = false
    @State private var tempFromDate = Date()
    @State private var tempToDate = Date()
    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PeriodType.allCases, id: \.self) { period in
                        PeriodChip(title: period.displayName, isSelected: selectedPeriod == period) {
                            if period == .custom { showDatePicker = true } else { onPeriodChange(period) }
                        }
                    }
                }
            }
            if selectedPeriod == .custom {
                Text("\(formatDate(fromDate)) - \(formatDate(toDate))")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DateRangePickerSheet(fromDate: $tempFromDate, toDate: $tempToDate) { from, to in
                onCustomRange(from, to)
                showDatePicker = false
            }
        }
        .onAppear { tempFromDate = fromDate; tempToDate = toDate }
    }
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
struct PeriodChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .black : AppTheme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? AppTheme.accent : AppTheme.cardBackground)
                .cornerRadius(20)
        }
    }
}

struct DateRangePickerSheet: View {
    @Binding var fromDate: Date
    @Binding var toDate: Date
    let onApply: (Date, Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedField: RangeField = .from
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(spacing: 20) {
                    HStack(spacing: 16) {
                        DateLabel(title: "From", date: fromDate, isSelected: selectedField == .from) {
                            selectedField = .from
                        }
                        Image(systemName: "arrow.right")
                            .foregroundColor(AppTheme.textSecondary)
                            .font(.caption)
                        DateLabel(title: "To", date: toDate, isSelected: selectedField == .to) {
                            selectedField = .to
                        }
                    }
                    CustomCalendarView(
                        fromDate: $fromDate,
                        toDate: $toDate,
                        selectedField: selectedField
                    )
                    Button("Apply") {
                        onApply(fromDate, toDate)
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.accent)
                    .cornerRadius(12)
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Select Date Range")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(AppTheme.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

struct DateLabel: View {
    let title: String
    let date: Date
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(AppTheme.textSecondary)
                Text(date.formatted(.dateTime.day().month()))
                    .font(.callout.weight(.semibold))
                    .foregroundColor(isSelected ? AppTheme.accent : AppTheme.textPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(isSelected ? AppTheme.accent.opacity(0.15) : AppTheme.cardBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? AppTheme.accent : Color.clear, lineWidth: 1.5)
            )
        }
    }
}


#Preview {
    PeriodSelectorPreviewContent()
}
struct PeriodSelectorPreviewContent: View {
    @State private var selectedPeriod: PeriodType = .week
    @State private var fromDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var toDate = Date()
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            PeriodSelectorView(
                selectedPeriod: selectedPeriod,
                fromDate: fromDate,
                toDate: toDate,
                onPeriodChange: { selectedPeriod = $0 },
                onCustomRange: { from, to in
                    fromDate = from
                    toDate = to
                    selectedPeriod = .custom
                }
            )
            .padding()
        }
        .preferredColorScheme(.dark)
    }
}
