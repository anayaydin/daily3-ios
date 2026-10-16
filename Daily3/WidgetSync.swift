import Foundation
import OSLog
import SwiftData
import WidgetKit

extension TodayWidgetSnapshot {
    init(entry: DailyEntry?, date: Date) {
        self.init(day: date, priorities: entry?.sortedTasks.map {
            WidgetPriority(slot: $0.slot, title: $0.title, isCompleted: $0.isCompleted)
        } ?? [])
    }
}

enum WidgetSync {
    static func publish(_ snapshot: TodayWidgetSnapshot, context: ModelContext) {
        do {
            try context.save()
            if try WidgetSnapshotStore.shared.write(snapshot) {
                WidgetCenter.shared.reloadTimelines(ofKind: Daily3WidgetConfiguration.kind)
            }
        } catch {
            Logger(subsystem: "com.anayaydin.Daily3", category: "Widget")
                .error("Could not share today's widget snapshot: \(error.localizedDescription, privacy: .public)")
        }
    }
}
