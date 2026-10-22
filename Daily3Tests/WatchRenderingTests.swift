import SwiftUI
import UIKit
import XCTest
@testable import Daily3

@MainActor
final class WatchRenderingTests: XCTestCase {
    func testWatchContentAtSmallWidthAndLargeText() throws {
        for (name, textSize, empty) in [
            ("Watch priorities", DynamicTypeSize.large, false),
            ("Watch empty", .large, true),
            ("Watch large text", .xxxLarge, false)
        ] {
            let snapshot = TodayWidgetSnapshot(day: .now, priorities: empty ? [] : [
                WidgetPriority(slot: 1, title: "Plan the day", isCompleted: true),
                WidgetPriority(slot: 2, title: "Build a longer priority without clipping the title", isCompleted: false),
                WidgetPriority(slot: 3, title: "Review", isCompleted: false)
            ])
            let content = WatchTodayView(snapshot: snapshot, status: "Sync pending", onToggle: { _ in })
                .frame(width: 180)
                .fixedSize(horizontal: false, vertical: true)
                .background(.black)
                .environment(\.colorScheme, .dark)
                .environment(\.dynamicTypeSize, textSize)
            let renderer = ImageRenderer(content: content)
            renderer.scale = 3
            let image = try XCTUnwrap(renderer.uiImage)
            XCTAssertEqual(image.size.width, 180)
            XCTAssertGreaterThan(try XCTUnwrap(image.pngData()).count, 2_000)
            let cgImage = try XCTUnwrap(image.cgImage)
            var pixels = [UInt8](repeating: 0, count: 60 * 100 * 4)
            try pixels.withUnsafeMutableBytes { buffer in
                let context = try XCTUnwrap(CGContext(
                    data: buffer.baseAddress, width: 60, height: 100,
                    bitsPerComponent: 8, bytesPerRow: 60 * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ))
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 60, height: 100))
            }
            let visiblePixels = stride(from: 0, to: pixels.count, by: 4).filter {
                pixels[$0] > 40 || pixels[$0 + 1] > 40 || pixels[$0 + 2] > 40
            }.count
            XCTAssertGreaterThan(visiblePixels, 100, "The shared content must not render as a blank image")
            let attachment = XCTAttachment(image: image)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
