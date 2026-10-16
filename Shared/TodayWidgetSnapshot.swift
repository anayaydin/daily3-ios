import Foundation

enum Daily3WidgetConfiguration {
    static let kind = "Daily3TodayWidget"
    static let appGroup = "group.com.anayaydin.Daily3"
    static let todayURL = URL(string: "daily3://today")!
}

struct WidgetPriority: Codable, Equatable, Identifiable {
    let slot: Int
    let title: String
    let isCompleted: Bool

    var id: Int { slot }
}

struct TodayWidgetSnapshot: Codable, Equatable {
    let day: Date
    let priorities: [WidgetPriority]

    var completedCount: Int {
        priorities.filter(\.isCompleted).count
    }

    init(day: Date, priorities: [WidgetPriority] = [], calendar: Calendar = .current) {
        self.day = calendar.startOfDay(for: day)
        self.priorities = (1...3).map { slot in
            let priority = priorities.first { $0.slot == slot }
            let title = priority?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return WidgetPriority(slot: slot, title: title, isCompleted: !title.isEmpty && priority?.isCompleted == true)
        }
    }

    func forDay(_ date: Date, calendar: Calendar = .current) -> TodayWidgetSnapshot {
        guard calendar.isDate(day, inSameDayAs: date) else {
            return TodayWidgetSnapshot(day: date, calendar: calendar)
        }
        return TodayWidgetSnapshot(day: date, priorities: priorities, calendar: calendar)
    }

    func nextDay(calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day)) ?? day.addingTimeInterval(86_400)
    }
}

struct WidgetSnapshotStore {
    private let directory: URL?

    static var shared: WidgetSnapshotStore {
        WidgetSnapshotStore(directory: FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Daily3WidgetConfiguration.appGroup
        ))
    }

    init(directory: URL?) {
        self.directory = directory
    }

    func read(for date: Date, calendar: Calendar = .current) -> TodayWidgetSnapshot {
        guard let directory,
              let data = try? Data(contentsOf: directory.appendingPathComponent("today-widget.json")),
              let snapshot = try? JSONDecoder().decode(TodayWidgetSnapshot.self, from: data) else {
            return TodayWidgetSnapshot(day: date, calendar: calendar)
        }
        return snapshot.forDay(date, calendar: calendar)
    }

    @discardableResult
    func write(_ snapshot: TodayWidgetSnapshot) throws -> Bool {
        guard let directory else { throw CocoaError(.fileNoSuchFile) }
        let url = directory.appendingPathComponent("today-widget.json")
        if let data = try? Data(contentsOf: url),
           let previous = try? JSONDecoder().decode(TodayWidgetSnapshot.self, from: data),
           previous == snapshot {
            return false
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
        return true
    }
}
