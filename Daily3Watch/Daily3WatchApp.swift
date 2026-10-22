import SwiftUI

@main
struct Daily3WatchApp: App {
    @State private var store = WatchSessionStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    ScrollView {
                        WatchTodayView(
                            snapshot: store.snapshot(for: timeline.date),
                            status: store.status(for: timeline.date),
                            onToggle: store.toggle
                        )
                    }
                }
                .navigationTitle("Daily 3")
                .toolbar {
                    Button("Refresh", systemImage: "arrow.clockwise") { store.refresh() }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("Refresh priorities")
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { store.refresh() }
            }
        }
    }
}
