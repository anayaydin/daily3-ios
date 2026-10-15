import Foundation
import Testing
@testable import Daily3

struct TaskStatisticsTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    private func entry(on date: Date) -> DailyEntry {
        let entry = DailyEntry(date: date)
        // DailyEntry uses the device calendar; fixtures use the test's UTC calendar.
        entry.date = date
        return entry
    }

    @Test func totalsExcludeEmptyPrioritiesAndFutureEntries() throws {
        let today = try date(2026, 10, 15)
        let complete = entry(on: try date(2026, 10, 13))
        for task in complete.tasks {
            task.title = "A priority"
            task.isCompleted = true
        }
        let partial = entry(on: today)
        partial.tasks[0].title = "Read"
        partial.tasks[0].isCompleted = true
        partial.tasks[1].title = "Build"
        partial.tasks[2].title = "  \n"
        partial.tasks[2].isCompleted = true
        let empty = entry(on: try date(2026, 10, 14))
        let future = entry(on: try date(2026, 10, 16))
        future.tasks[0].title = "Tomorrow"
        future.tasks[0].isCompleted = true

        let statistics = TaskStatistics(entries: [future, empty, partial, complete], today: today, calendar: calendar)

        #expect(statistics.totalCompleted == 4)
        #expect(statistics.totalPlanned == 5)
        #expect(statistics.completeDays == 1)
        #expect(statistics.completionRate == 0.8)
        #expect(statistics.dailyActivity(for: .week).reduce(0) { $0 + $1.completedCount } == 4)
    }

    @Test func emptyHistoryHasNoCompletionRate() throws {
        let statistics = TaskStatistics(entries: [], today: try date(2026, 10, 15), calendar: calendar)
        #expect(statistics.totalCompleted == 0)
        #expect(statistics.totalPlanned == 0)
        #expect(statistics.completeDays == 0)
        #expect(statistics.completionRate == nil)
        #expect(statistics.dailyActivity(for: .month).allSatisfy { $0.completedCount == 0 })
    }

    @Test func plannedButUnfinishedPrioritiesHaveZeroCompletionRate() throws {
        let today = try date(2026, 10, 15)
        let entry = entry(on: today)
        entry.tasks[0].title = "An unfinished priority"
        let statistics = TaskStatistics(entries: [entry], today: today, calendar: calendar)
        #expect(statistics.completionRate == 0)
    }

    @Test func activityIncludesMissingDaysAndCrossesLeapMonthBoundary() throws {
        let today = try date(2024, 3, 2)
        let leapDay = entry(on: try date(2024, 2, 29))
        leapDay.tasks[0].title = "Leap day priority"
        leapDay.tasks[0].isCompleted = true
        let old = entry(on: try date(2024, 1, 1))
        old.tasks[0].title = "Old priority"
        old.tasks[0].isCompleted = true
        let statistics = TaskStatistics(entries: [old, leapDay], today: today, calendar: calendar)
        let week = statistics.dailyActivity(for: .week)
        let month = statistics.dailyActivity(for: .month)

        #expect(week.count == 7)
        #expect(week.first?.date == (try date(2024, 2, 25)))
        #expect(week.last?.date == today)
        #expect(week.map(\.completedCount) == [0, 0, 0, 0, 1, 0, 0])
        #expect(month.count == 30)
        #expect(month.first?.date == (try date(2024, 2, 2)))
        #expect(month.reduce(0) { $0 + $1.completedCount } == 1)
        #expect(statistics.totalCompleted == 2)
    }

    @Test func activityKeepsLocalMidnightAcrossDaylightSavingChange() throws {
        var calendar = calendar
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 15)))
        let statistics = TaskStatistics(entries: [], today: today, calendar: calendar)
        let activity = statistics.dailyActivity(for: .week)

        #expect(activity.map { calendar.component(.day, from: $0.date) } == [4, 5, 6, 7, 8, 9, 10])
        #expect(activity.allSatisfy { calendar.component(.hour, from: $0.date) == 0 })
    }
}
