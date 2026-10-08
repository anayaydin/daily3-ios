//
//  Daily3Tests.swift
//  Daily3Tests
//
//  Created by Ayse Nur AYAYDIN on 7.10.2026.
//

import Testing
@testable import Daily3

struct Daily3Tests {

    @Test func newDayStartsWithThreeEmptyTasks() {
        let todayTasks = TodayTasks()

        #expect(todayTasks.tasks.count == 3)
        #expect(todayTasks.filledCount == 0)
        #expect(todayTasks.completedCount == 0)
        #expect(todayTasks.isDayComplete == false)
    }

    @Test func completedCountOnlyIncludesFilledTasks() {
        var todayTasks = TodayTasks()
        todayTasks.tasks[0].title = "Write project README"
        todayTasks.tasks[0].isCompleted = true
        todayTasks.tasks[1].isCompleted = true

        #expect(todayTasks.filledCount == 1)
        #expect(todayTasks.completedCount == 1)
    }

    @Test func dayIsCompleteWhenAllThreeFilledTasksAreCompleted() {
        var todayTasks = TodayTasks()

        todayTasks.tasks[0] = DailyTask(id: 1, title: "Plan", isCompleted: true)
        todayTasks.tasks[1] = DailyTask(id: 2, title: "Build", isCompleted: true)
        todayTasks.tasks[2] = DailyTask(id: 3, title: "Review", isCompleted: true)

        #expect(todayTasks.isDayComplete)
    }

}
