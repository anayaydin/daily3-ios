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
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [DailyEntry.self, DailyTaskItem.self])
    }
}
