//
//  DailyEntry.swift
//  Daily3
//
//  Created by Ayse Nur AYAYDIN on 9.10.2026.
//

import Foundation
import SwiftData

@Model
final class DailyEntry {
    var date: Date
    @Relationship(deleteRule: .cascade) var tasks: [DailyTaskItem]

    init(date: Date, tasks: [DailyTaskItem] = []) {
        self.date = Calendar.current.startOfDay(for: date)
        self.tasks = tasks.isEmpty ? (1...3).map { DailyTaskItem(slot: $0) } : tasks
    }

    var sortedTasks: [DailyTaskItem] {
        tasks.sorted { $0.slot < $1.slot }
    }

    var completedCount: Int {
        tasks.filter { $0.isCompleted && $0.isFilled }.count
    }

    var filledCount: Int {
        tasks.filter(\.isFilled).count
    }

    var isDayComplete: Bool {
        completedCount == 3
    }
}
