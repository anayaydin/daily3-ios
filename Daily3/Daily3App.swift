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
    private let container: ModelContainer = {
        do {
            return try Daily3Storage.makeContainer()
        } catch {
            fatalError("Could not open the Daily 3 store: \(error.localizedDescription)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
