import Testing
import Foundation
import SwiftData
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import SipfolioCore

private func temporaryRoot() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioTests-\(UUID().uuidString)", isDirectory: true)
}

func testPNG(width: Int = 60, height: Int = 100) throws -> Data {
    let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.4, alpha: 1))
    context.fill(CGRect(x: 10, y: 10, width: width - 20, height: height - 20))
    let image = try #require(context.makeImage())
    let data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
    return data as Data
}

@Test @MainActor
func collectionSurvivesReopeningIncludingImages() throws {
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let image = try testPNG()
    var savedID: UUID!
    do {
        let store = try CollectionStore(root: root)
        let drink = try store.add(name: "  我的金酒  ", category: "金酒", notes: " 黄瓜与花香 ", original: image, sticker: image, thumbnail: image, usesOriginalPhoto: false)
        savedID = drink.id
    }
    let reopened = try CollectionStore(root: root)
    let records = try reopened.allDrinks()
    #expect(records.count == 1)
    #expect(records[0].id == savedID)
    #expect(records[0].name == "我的金酒")
    #expect(records[0].notes == "黄瓜与花香")
    #expect(try Data(contentsOf: reopened.images.imageURL(for: savedID)) == image)
    #expect(try Data(contentsOf: reopened.images.imageURL(for: savedID, original: true)) == image)
    #expect(try Data(contentsOf: reopened.images.thumbnailURL(for: savedID)) == image)
}

@Test @MainActor
func blankNamesNeverCreateRecordsOrPhotos() throws {
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root, inMemory: true)
    let image = try testPNG()
    #expect(throws: SipfolioError.self) {
        try store.add(name: " \n ", category: "其他", notes: "", original: image, sticker: image, thumbnail: image, usesOriginalPhoto: true)
    }
    #expect(try store.allDrinks().isEmpty)
    #expect(!FileManager.default.fileExists(atPath: store.images.root.path))
}

@Test @MainActor
func imageWriteFailureNeverInsertsCollectionRecord() throws {
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root, inMemory: true)
    // A regular file at Images makes creation of the per-record directory fail.
    try Data("blocked".utf8).write(to: store.images.root)
    let image = try testPNG()
    #expect(throws: (any Error).self) {
        try store.add(name: "测试酒", category: "其他", notes: "", original: image, sticker: image, thumbnail: image, usesOriginalPhoto: false)
    }
    #expect(try store.allDrinks().isEmpty)
}

@Test @MainActor
func editAndDeleteRespectPersistentImages() throws {
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root)
    let image = try testPNG()
    let drink = try store.add(name: "旧酒名", category: "其他", notes: "", original: image, sticker: image, thumbnail: image, usesOriginalPhoto: true)
    let id = drink.id
    #expect(throws: SipfolioError.self) { try store.update(drink, name: " ", category: "金酒", notes: "") }
    #expect(drink.name == "旧酒名")
    try store.update(drink, name: "新酒名", category: "金酒", notes: "在朋友家喝的")
    let reopened = try CollectionStore(root: root)
    #expect(try reopened.allDrinks().first?.name == "新酒名")
    #expect(try reopened.allDrinks().first?.category == "金酒")
    #expect(FileManager.default.fileExists(atPath: store.images.imageURL(for: id).path))
    try store.delete(drink)
    #expect(try store.allDrinks().isEmpty)
    #expect(!FileManager.default.fileExists(atPath: store.images.directory(for: id).path))
    let afterDelete = try CollectionStore(root: root)
    #expect(try afterDelete.allDrinks().isEmpty)
}

@Test @MainActor
func sameWineCannotBeAddedOrRenamedTwice() throws {
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root, inMemory: true)
    let image = try testPNG()
    let first = try store.add(name: "Hendrick's Gin", category: "金酒", notes: "", original: image, sticker: image, thumbnail: image, usesOriginalPhoto: true)
    #expect(throws: SipfolioError.self) {
        try store.add(name: " hendrick's gin ", category: "金酒", notes: "", original: image, sticker: image, thumbnail: image, usesOriginalPhoto: true)
    }
    #expect(try store.allDrinks().count == 1)
    let edition = try store.add(name: "Hendrick's Gin 限量版", category: "金酒", notes: "", original: image, sticker: image, thumbnail: image, usesOriginalPhoto: true)
    #expect(throws: SipfolioError.self) { try store.update(edition, name: first.name, category: "金酒", notes: "") }
    #expect(edition.name == "Hendrick's Gin 限量版")
    #expect(try FileManager.default.contentsOfDirectory(atPath: store.images.root.path).count == 2)
}

@Test
func normalizationDownsizesAndKeepsTransparency() async throws {
    let service = BottleCutoutService()
    let output = try await service.normalizedPNG(from: testPNG(width: 600, height: 1000), maxPixelSize: 200)
    let source = try #require(CGImageSourceCreateWithData(output as CFData, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(image.width == 120)
    #expect(image.height == 200)
    #expect(image.alphaInfo != .none && image.alphaInfo != .noneSkipLast && image.alphaInfo != .noneSkipFirst)
}

@Test
func invalidPhotoProvidesRecoverableError() async {
    let service = BottleCutoutService()
    await #expect(throws: SipfolioError.self) {
        try await service.normalizedPNG(from: Data("not an image".utf8), maxPixelSize: 420)
    }
    await #expect(throws: SipfolioError.self) {
        try await service.cutout(from: Data("not an image".utf8))
    }
}
