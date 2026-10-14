//
//  CalendarView.swift
//  Daily3
//
//  Created by Ayse Nur AYAYDIN on 12.10.2026.
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query(sort: \DailyEntry.date) private var entries: [DailyEntry]
    @State private var displayedMonth = Calendar.current.startOfMonth(for: .now)
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let startIndex = calendar.firstWeekday - 1
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    private var monthDates: [Date?] {
        calendar.monthGridDates(containing: displayedMonth)
    }

    private var selectedEntry: DailyEntry? {
        entry(for: selectedDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    monthHeader
                    calendarGrid
                    selectedDaySummary
                }
                .padding(20)
            }
            .navigationTitle("Calendar")
            .background(Color(.systemGroupedBackground))
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Previous month")

            Spacer()

            Text(monthTitle)
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button {
                returnToToday()
            } label: {
                Image(systemName: "location")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Return to today")

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Next month")
        }
    }

    private var calendarGrid: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(monthDates.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let isFuture = calendar.isDateInFuture(date)

                        CalendarDayCell(
                            date: date,
                            entry: entry(for: date),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            isFuture: isFuture
                        )
                        .onTapGesture {
                            selectDate(date)
                        }
                        .allowsHitTesting(!isFuture)
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var selectedDaySummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                .font(.headline)

            if calendar.isDateInFuture(selectedDate) {
                ContentUnavailableView(
                    "Future day",
                    systemImage: "lock",
                    description: Text("Daily 3 records are created on the day itself.")
                )
                .frame(maxWidth: .infinity)
            } else if let selectedEntry {
                ProgressView(value: Double(selectedEntry.completedCount), total: 3)
                    .accessibilityLabel("Selected day progress")
                    .accessibilityValue("\(selectedEntry.completedCount) of 3 completed")

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(selectedEntry.sortedTasks, id: \.slot) { task in
                        HStack(spacing: 10) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.isCompleted ? .green : .secondary)

                            Text(task.isFilled ? task.title : "Priority \(task.slot)")
                                .foregroundStyle(task.isFilled ? .primary : .secondary)

                            Spacer()
                        }
                        .font(.body)
                    }
                }
            } else {
                ContentUnavailableView(
                    "No priorities recorded",
                    systemImage: "calendar",
                    description: Text("Choose a day that has Daily 3 tasks.")
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func entry(for date: Date) -> DailyEntry? {
        entries.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func selectDate(_ date: Date) {
        guard !calendar.isDateInFuture(date) else { return }
        selectedDate = calendar.startOfDay(for: date)
    }

    private func moveMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else {
            return
        }

        displayedMonth = calendar.startOfMonth(for: newMonth)
        selectedDate = calendar.isDateInFuture(displayedMonth) ? calendar.startOfDay(for: .now) : displayedMonth
    }

    private func returnToToday() {
        selectedDate = calendar.startOfDay(for: .now)
        displayedMonth = calendar.startOfMonth(for: .now)
    }
}

private struct CalendarDayCell: View {
    let date: Date
    let entry: DailyEntry?
    let isSelected: Bool
    let isToday: Bool
    let isFuture: Bool

    private var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }

    private var completedCount: Int {
        entry?.completedCount ?? 0
    }

    private var intensityColor: Color {
        if isFuture {
            return Color(.systemGray5)
        }

        switch completedCount {
        case 3:
            return .green
        case 2:
            return .green.opacity(0.65)
        case 1:
            return .green.opacity(0.35)
        default:
            return Color(.tertiarySystemGroupedBackground)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(intensityColor)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)

            VStack(spacing: 6) {
                Text("\(dayNumber)")
                    .font(.subheadline)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isFuture ? .secondary : .primary)

                if entry != nil {
                    Text("\(completedCount)/3")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .opacity(isFuture ? 0.55 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(date.formatted(.dateTime.month(.wide).day().year()))
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        if isFuture {
            return "Future day"
        }

        return entry == nil ? "No priorities recorded" : "\(completedCount) of 3 completed"
    }
}
