import SwiftUI
import UIKit
import XCTest
@testable import Daily3

@MainActor
final class WidgetRenderingTests: XCTestCase {
    func testSmallAndMediumWidgetLayouts() throws {
        let priorities = [
            WidgetPriority(slot: 1, title: "Plan the day", isCompleted: true),
            WidgetPriority(slot: 2, title: "Build something", isCompleted: false),
            WidgetPriority(slot: 3, title: "Take a walk", isCompleted: false)
        ]
        let snapshot = TodayWidgetSnapshot(day: .now, priorities: priorities)
        try capture(snapshot, compact: true, name: "Small widget")
        try capture(snapshot, compact: false, name: "Medium widget")
        try capture(TodayWidgetSnapshot(day: .now), compact: true, name: "Empty widget")
        let completed = priorities.map { WidgetPriority(slot: $0.slot, title: $0.title, isCompleted: true) }
        try capture(TodayWidgetSnapshot(day: .now, priorities: completed), compact: false, name: "Completed widget dark", colorScheme: .dark)
        let longTitles = priorities.map {
            WidgetPriority(slot: $0.slot, title: "A longer priority title that should truncate cleanly", isCompleted: $0.isCompleted)
        }
        try capture(TodayWidgetSnapshot(day: .now, priorities: longTitles), compact: true, name: "Small widget large text", textSize: .xxxLarge)
    }

    private func capture(
        _ snapshot: TodayWidgetSnapshot,
        compact: Bool,
        name: String,
        colorScheme: ColorScheme = .light,
        textSize: DynamicTypeSize = .large
    ) throws {
        let width: CGFloat = compact ? 170 : 360
        let content = TodayWidgetContent(snapshot: snapshot, isCompact: compact)
            .padding(16)
            .frame(width: width, height: 170)
            .background(colorScheme == .dark ? Color.black : Color.white)
            .environment(\.colorScheme, colorScheme)
            .environment(\.dynamicTypeSize, textSize)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage)
        XCTAssertEqual(image.size.width, width)
        XCTAssertEqual(image.size.height, 170)
        XCTAssertGreaterThan(try XCTUnwrap(image.pngData()).count, 2_000)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
