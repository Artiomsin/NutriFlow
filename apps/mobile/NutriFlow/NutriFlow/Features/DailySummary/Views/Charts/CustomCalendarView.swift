import SwiftUI

struct CustomCalendarView: View {
    @Binding var fromDate: Date
    @Binding var toDate: Date
    let selectedField: RangeField
    @State private var currentMonth: Date = Date()

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    private var daySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        return symbols
    }

    var body: some View {
        VStack(spacing: 16) {
            monthHeader
            weekDayHeader
            calendarGrid
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.body)
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.cardBackground)
                    .cornerRadius(8)
            }

            Spacer()

            Text(monthYearString)
                .font(.headline.weight(.semibold))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Button { changeMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(canGoForward ? AppTheme.textSecondary : AppTheme.textSecondary.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .background(canGoForward ? AppTheme.cardBackground : Color.clear)
                    .cornerRadius(8)
            }
            .disabled(!canGoForward)
        }
        .padding(.horizontal, 4)
    }

    private var canGoForward: Bool {
        calendar.compare(currentMonth, to: Date(), toGranularity: .month) == .orderedAscending
    }

    private var weekDayHeader: some View {
        HStack(spacing: 0) {
            ForEach(daySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(days, id: \.offset) { item in
                if let date = item.date {
                    DayCell(
                        date: date,
                        isSelected: isSelected(date),
                        isInRange: isInRange(date),
                        isDisabled: isFutureDate(date),
                        isStartOfRange: calendar.isDate(date, inSameDayAs: fromDate),
                        isEndOfRange: calendar.isDate(date, inSameDayAs: toDate),
                        belongsToMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
                    )
                    .onTapGesture { if !isFutureDate(date) { selectDate(date) } }
                } else {
                    Color.clear
                        .aspectRatio(1, contentMode: .fill)
                }
            }
        }
    }

    private func changeMonth(_ offset: Int) {
        if let newDate = calendar.date(byAdding: .month, value: offset, to: currentMonth) {
            currentMonth = newDate
        }
    }

    private func selectDate(_ date: Date) {
        guard !isFutureDate(date) else { return }
        if selectedField == .from {
            fromDate = date
            if date > toDate { toDate = date }
        } else {
            toDate = date
            if date < fromDate { fromDate = date }
        }
    }

    private func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: fromDate) || calendar.isDate(date, inSameDayAs: toDate)
    }

    private func isInRange(_ date: Date) -> Bool {
        date > fromDate && date < toDate
    }

    private func isFutureDate(_ date: Date) -> Bool {
        calendar.compare(date, to: Date(), toGranularity: .day) == .orderedDescending
    }

    private var days: [(offset: Int, date: Date?)] {
        guard let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)),
              let range = calendar.range(of: .day, in: .month, for: currentMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1
        let numberOfDays = range.count
        var result: [(Int, Date?)] = []

        for _ in 0..<firstWeekday {
            result.append((result.count, nil))
        }

        for day in 1...numberOfDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                result.append((result.count, date))
            }
        }

        let remaining = 7 - (result.count % 7)
        if remaining < 7 {
            for _ in 0..<remaining {
                result.append((result.count, nil))
            }
        }

        return result
    }
}


struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isInRange: Bool
    let isDisabled: Bool
    let isStartOfRange: Bool
    let isEndOfRange: Bool
    let belongsToMonth: Bool

    private let calendar = Calendar.current

    var body: some View {
        Text("\(calendar.component(.day, from: date))")
            .font(.subheadline.weight(isSelected ? .bold : .regular))
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(backgroundView)
            .cornerRadius(8)
            .opacity(isDisabled ? 0.3 : 1)
    }

    private var foregroundColor: Color {
        if isSelected { return .black }
        if !belongsToMonth { return Color.white.opacity(0.3) }
        return .white
    }

    @ViewBuilder
    private var backgroundView: some View {
        if isSelected {
            AppTheme.accent
        } else if isInRange && !isDisabled {
            AppTheme.accent.opacity(0.15)
        } else {
            Color.clear
        }
    }
}


#Preview {
    CustomCalendarPreview()
}

struct CustomCalendarPreview: View {
    @State private var fromDate = Date()
    @State private var toDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var selectedField: RangeField = .from

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            CustomCalendarView(
                fromDate: $fromDate,
                toDate: $toDate,
                selectedField: selectedField
            )
            .padding()
        }
    }
}
