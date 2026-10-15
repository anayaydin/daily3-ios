import Foundation

enum StatisticsPeriod: Int, CaseIterable, Identifiable {
    case week = 7
    case month = 30

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .week: return "7 Days"
        case .month: return "30 Days"
        }
    }
}

struct DailyStatistics: Identifiable {
    let date: Date
    let completedCount: Int
    let filledCount: Int

    var id: Date { date }
}

struct TaskStatistics {
    let totalCompleted: Int
    let totalPlanned: Int
    let completeDays: Int
    private let countsByDay: [Date: DailyStatistics]
    private let today: Date
    private let calendar: Calendar

    var completionRate: Double? {
        guard totalPlanned > 0 else { return nil }
        return Double(totalCompleted) / Double(totalPlanned)
    }

    init(entries: [DailyEntry], today: Date = .now, calendar: Calendar = .current) {
        let todayStart = calendar.startOfDay(for: today)
        self.calendar = calendar
        self.today = todayStart

        let pastAndToday = entries.filter {
            calendar.startOfDay(for: $0.date) <= todayStart
        }
        totalCompleted = pastAndToday.reduce(0) { $0 + $1.completedCount }
        totalPlanned = pastAndToday.reduce(0) { $0 + $1.filledCount }
        completeDays = pastAndToday.filter(\.isDayComplete).count

        countsByDay = Dictionary(grouping: pastAndToday) {
            calendar.startOfDay(for: $0.date)
        }.mapValues { entries in
            DailyStatistics(
                date: calendar.startOfDay(for: entries[0].date),
                completedCount: entries.reduce(0) { $0 + $1.completedCount },
                filledCount: entries.reduce(0) { $0 + $1.filledCount }
            )
        }
    }

    func dailyActivity(for period: StatisticsPeriod) -> [DailyStatistics] {
        // Calendar arithmetic keeps each point on a local day across DST changes.
        (0..<period.rawValue).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }
            return countsByDay[date] ?? DailyStatistics(date: date, completedCount: 0, filledCount: 0)
        }
    }
}
