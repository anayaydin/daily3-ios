//
//  Daily3App.swift
//  Daily3
//
//  Created by Ayse Nur AYAYDIN on 7.10.2026.
//

import SwiftUI
import SwiftData

@main
struct Daily3App: App {
    private let container: ModelContainer
    private let watchSync: PhoneWatchSync

    init() {
        do {
            let container = try Daily3Storage.makeContainer()
            self.container = container
            watchSync = PhoneWatchSync(context: container.mainContext)
        } catch {
            fatalError("Could not open the Daily 3 store: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(onTodayChange: watchSync.publishCurrent)
        }
        .modelContainer(container)
    }
}
