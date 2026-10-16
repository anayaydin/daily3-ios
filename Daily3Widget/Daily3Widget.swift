import SwiftUI
import WidgetKit

struct Daily3WidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: TodayWidgetSnapshot
}

struct Daily3WidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> Daily3WidgetEntry {
        previewEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (Daily3WidgetEntry) -> Void) {
        if context.isPreview {
            completion(previewEntry())
        } else {
            let now = Date.now
            completion(Daily3WidgetEntry(date: now, snapshot: WidgetSnapshotStore.shared.read(for: now)))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Daily3WidgetEntry>) -> Void) {
        let now = Date.now
        let snapshot = WidgetSnapshotStore.shared.read(for: now)
        let tomorrow = snapshot.nextDay()
        let entries = [
            Daily3WidgetEntry(date: now, snapshot: snapshot),
            Daily3WidgetEntry(date: tomorrow, snapshot: TodayWidgetSnapshot(day: tomorrow))
        ]
        completion(Timeline(entries: entries, policy: .after(tomorrow)))
    }

    private func previewEntry() -> Daily3WidgetEntry {
        let now = Date.now
        return Daily3WidgetEntry(date: now, snapshot: TodayWidgetSnapshot(day: now, priorities: [
            WidgetPriority(slot: 1, title: "Plan the day", isCompleted: true),
            WidgetPriority(slot: 2, title: "Build something", isCompleted: false),
            WidgetPriority(slot: 3, title: "Take a walk", isCompleted: false)
        ]))
    }
}

struct Daily3WidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: Daily3WidgetEntry

    var body: some View {
        TodayWidgetContent(snapshot: entry.snapshot, isCompact: family == .systemSmall)
            .widgetURL(Daily3WidgetConfiguration.todayURL)
            .containerBackground(.background, for: .widget)
    }
}

@main
struct Daily3TodayWidget: Widget {
    let kind = Daily3WidgetConfiguration.kind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Daily3WidgetProvider()) { entry in
            Daily3WidgetView(entry: entry)
        }
        .configurationDisplayName("Daily 3")
        .description("Today's three priorities and daily progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    Daily3TodayWidget()
} timeline: {
    Daily3WidgetEntry(date: .now, snapshot: TodayWidgetSnapshot(day: .now))
}

#Preview(as: .systemMedium) {
    Daily3TodayWidget()
} timeline: {
    Daily3WidgetEntry(date: .now, snapshot: TodayWidgetSnapshot(day: .now, priorities: [
        WidgetPriority(slot: 1, title: "Plan the day", isCompleted: true),
        WidgetPriority(slot: 2, title: "Build something", isCompleted: false),
        WidgetPriority(slot: 3, title: "Take a walk", isCompleted: false)
    ]))
}
