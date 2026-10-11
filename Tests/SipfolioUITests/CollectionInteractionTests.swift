import Testing
import SwiftUI
import AppKit
import SipfolioCore
@testable import Sipfolio

@Test(arguments: [0, 3]) @MainActor
func collectionShelvesCanSwitchBothWaysWithEmptyBooks(photoCount: Int) async throws {
    _ = NSApplication.shared
    var selection = CollectionShelf.photos
    let binding = Binding(get: { selection }, set: { selection = $0 })
    let host = NSHostingView(rootView: CollectionShelfNavigation(selection: binding, bottleCount: 1, photoCount: photoCount, textCount: photoCount).frame(width: 174))
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 174, height: 190), styleMask: .borderless, backing: .buffered, defer: false)
    window.contentView = host
    window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
    window.orderBack(nil)
    defer { window.orderOut(nil); window.contentView = nil }
    host.frame = NSRect(x: 0, y: 0, width: 174, height: 190)
    host.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(100))
    for (y, expected) in [(30.0, CollectionShelf.text), (95.0, .photos), (160.0, .bottles), (30.0, .text), (95.0, .photos)] {
        let point = NSPoint(x: 80, y: y)
        _ = try #require(host.hitTest(host.convert(point, from: nil)))
        let down = try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        let up = try #require(NSEvent.mouseEvent(with: .leftMouseUp, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, eventNumber: 2, clickCount: 1, pressure: 0))
        window.sendEvent(down)
        window.sendEvent(up)
        try await Task.sleep(for: .milliseconds(30))
        #expect(selection == expected)
    }
}

@Test @MainActor
func completeCollectionSwitchesBackFromTextBesideTallPhoto() async throws {
    _ = NSApplication.shared
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioShelfClick-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root, inMemory: true)
    let recipe = try store.addCocktail(name: "有图配方", ingredients: "金酒 — 15 ml\n汤力水 — 45 ml", steps: "加冰搅拌。")
    _ = try store.addCocktail(name: "文字配方", ingredients: "威士忌 — 45 ml\n苏打水 — 135 ml", steps: "加冰轻轻搅拌。")
    let image = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 100, pixelsHigh: 1200, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
    let photo = try #require(image.representation(using: .png, properties: [:]))
    try store.saveCocktailPhoto(id: recipe.id, original: photo, sticker: photo, thumbnail: photo, metadata: .init(provider: "用户照片"))
    var selectedShelf: CollectionShelf?
    let host = NSHostingView(rootView: CollectionView(store: store, isAdding: .constant(false), initiallyShowingCocktails: true, onShelfChange: { selectedShelf = $0 }).modelContainer(store.container))
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 774), styleMask: .borderless, backing: .buffered, defer: false)
    window.contentView = host
    window.setFrameOrigin(NSPoint(x: -20000, y: -20000)); window.orderBack(nil)
    defer { window.orderOut(nil); window.contentView = nil }
    host.frame = NSRect(x: 0, y: 0, width: 1180, height: 774)
    host.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(300))
    func waitForShelf(_ expected: CollectionShelf) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while selectedShelf != expected, ContinuousClock.now < deadline {
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(selectedShelf == expected)
    }
    func click(_ y: CGFloat) throws {
        let point = NSPoint(x: 90, y: y)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0))
            window.sendEvent(event)
        }
    }
    // Observe the full view's selection after dispatched mouse events, not PNG equality.
    // Font rasterization, async image loading and focus can differ across macOS runners.
    try await waitForShelf(.photos)
    try click(461)
    try await waitForShelf(.text)
    try click(526)
    try await waitForShelf(.photos)
}
