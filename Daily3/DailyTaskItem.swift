//
//  DailyTaskItem.swift
//  Daily3
//
//  Created by Ayse Nur AYAYDIN on 9.10.2026.
//

import Foundation
import SwiftData

@Model
final class DailyTaskItem {
    var slot: Int
    var title: String
    var isCompleted: Bool

    init(slot: Int, title: String = "", isCompleted: Bool = false) {
        self.slot = slot
        self.title = title
        self.isCompleted = isCompleted
    }

    var isFilled: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
