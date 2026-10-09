//
//  Daily3Tests.swift
//  Daily3Tests
//
//  Created by Ayse Nur AYAYDIN on 7.10.2026.
//

import Foundation
import SwiftData
import Testing
@testable import Daily3

struct Daily3Tests {

    @Test func newDayStartsWithThreeEmptyTasks() {
        let entry = DailyEntry(date: .now)

        #expect(entry.tasks.count == 3)
        #expect(entry.filledCount == 0)
        #expect(entry.completedCount == 0)
        #expect(entry.isDayComplete == false)
    }

    @Test func completedCountOnlyIncludesFilledTasks() {
        let entry = DailyEntry(date: .now)
        entry.tasks[0].title = "Write project README"
        entry.tasks[0].isCompleted = true
        entry.tasks[1].isCompleted = true

        #expect(entry.filledCount == 1)
        #expect(entry.completedCount == 1)
    }

    @Test func dayIsCompleteWhenAllThreeFilledTasksAreCompleted() {
        let entry = DailyEntry(date: .now)

        entry.tasks[0].title = "Plan"
        entry.tasks[0].isCompleted = true
        entry.tasks[1].title = "Build"
        entry.tasks[1].isCompleted = true
        entry.tasks[2].title = "Review"
        entry.tasks[2].isCompleted = true

        #expect(entry.isDayComplete)
    }

    @Test func entryCanBeSavedInSwiftDataContainer() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: DailyEntry.self,
            DailyTaskItem.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let entry = DailyEntry(date: .now)

        entry.tasks[0].title = "Plan the day"
        context.insert(entry)
        try context.save()

        let savedEntries = try context.fetch(FetchDescriptor<DailyEntry>())

        #expect(savedEntries.count == 1)
        #expect(savedEntries[0].tasks.count == 3)
        #expect(savedEntries[0].filledCount == 1)
    }

}
