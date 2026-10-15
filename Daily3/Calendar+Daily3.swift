//
//  Calendar+Daily3.swift
//  Daily3
//
//  Created by Ayse Nur AYAYDIN on 12.10.2026.
//

import Foundation

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }

    func monthGridDates(containing date: Date) -> [Date?] {
        let monthStart = startOfMonth(for: date)
        guard let dayRange = range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        let weekday = component(.weekday, from: monthStart)
        let leadingEmptyDays = (weekday - firstWeekday + 7) % 7
        let dates = dayRange.compactMap { day -> Date? in
            self.date(byAdding: .day, value: day - 1, to: monthStart)
        }

        var grid: [Date?] = Array(repeating: nil, count: leadingEmptyDays) + dates
        while grid.count % 7 != 0 {
            grid.append(nil)
        }

        return grid
    }

    func isDateInToday(_ date: Date) -> Bool {
        isDate(date, inSameDayAs: .now)
    }

    func isDateInFuture(_ date: Date) -> Bool {
        startOfDay(for: date) > startOfDay(for: .now)
    }
}
