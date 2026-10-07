import Foundation
import SwiftData
import Testing
@testable import SipfolioCore

// Matches the stored properties and entity name shipped in 0.2.0.
private enum LegacyCollectionSchema {
    @Model final class Drink {
        @Attribute(.unique) var id: UUID
        var name: String
        var category: String
        var notes: String
        var createdAt: Date
        var usesOriginalPhoto: Bool
        init(id: UUID, date: Date) {
            self.id = id; name = "旧版金酒"; category = "金酒"; notes = "升级前的备注"
            createdAt = date; usesOriginalPhoto = false
        }
    }
}

@Test @MainActor
func oldSchemaMigratesWithoutLosingDatePhotosOrKnowledge() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioMigration-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let id = UUID()
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let images = ImageStore(root: root.appendingPathComponent("Images"))
    let image = try testPNG()
    let knowledge = DrinkKnowledge(name: "旧版金酒", category: "金酒", confidence: "high", introduction: "原先保存的介绍", flavors: ["杜松子"], cocktails: ["Martini"])
    do {
        let schema = Schema([LegacyCollectionSchema.Drink.self])
        let configuration = ModelConfiguration(schema: schema, url: root.appendingPathComponent("Sipfolio.store"), cloudKitDatabase: .none)
        let old = try ModelContainer(for: schema, configurations: [configuration])
        old.mainContext.insert(LegacyCollectionSchema.Drink(id: id, date: date))
        try old.mainContext.save()
        try images.save(id: id, original: image, sticker: image, thumbnail: image, knowledge: knowledge)
    }
    let current = try CollectionStore(root: root)
    let drink = try #require(current.allDrinks().first)
    #expect(drink.id == id && drink.name == "旧版金酒" && drink.notes == "升级前的备注")
    #expect(drink.tasteVariant == nil && drink.bottleYear == nil)
    #expect(drink.collectionDate == date && drink.createdAt == date)
    #expect(try Data(contentsOf: current.images.imageURL(for: id)) == image)
    #expect(try current.images.loadKnowledge(for: id) == knowledge)
    let purchased = Date(timeIntervalSince1970: 1_500_000_000)
    try current.update(drink, name: drink.name, category: drink.category, notes: drink.notes, tasteVariant: "经典", bottleYear: "2020", collectionDate: purchased)
    let reopened = try CollectionStore(root: root)
    let saved = try #require(reopened.allDrinks().first)
    #expect(saved.collectionDate == purchased && saved.createdAt == date)
    #expect(saved.tasteVariant == "经典" && saved.bottleYear == "2020")
}

@Test @MainActor
func variantAndYearDistinguishSameNamedWines() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioVariants-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root)
    let image = try testPNG()
    func add(_ variant: String, _ year: String) throws -> Drink {
        try store.add(name: "林德莱姆", category: "金酒", notes: "", original: image, sticker: image, thumbnail: image, usesOriginalPhoto: false, tasteVariant: variant, bottleYear: year)
    }
    let classic = try add("经典", "2020")
    let bergamot = try add("佛手柑", "2020")
    _ = try add("经典", "2021")
    #expect(try store.allDrinks().count == 3)
    #expect(throws: SipfolioError.self) { try add(" 经典 ", " 2020 ") }
    #expect(throws: SipfolioError.self) {
        try store.update(bergamot, name: classic.name, category: "金酒", notes: "", tasteVariant: "经典", bottleYear: "2020")
    }
    #expect(bergamot.tasteVariant == "佛手柑")
    try store.update(classic, name: classic.name, category: classic.category, notes: "", tasteVariant: "", bottleYear: "")
    #expect(classic.tasteVariant == nil && classic.bottleYear == nil)
    let reopened = try CollectionStore(root: root)
    #expect(try reopened.allDrinks().count == 3)
}

@Test @MainActor
func aiEnrichmentPreservesManualVariantYearAndDate() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioManual-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root)
    let image = try testPNG()
    let date = Date(timeIntervalSince1970: 1_650_000_000)
    let drink = try store.add(name: "测试金酒", category: "金酒", notes: "手动备注", original: image, sticker: image, thumbnail: image, usesOriginalPhoto: false, tasteVariant: "佛手柑", bottleYear: "2021", collectionDate: date)
    let knowledge = DrinkKnowledge(name: "测试金酒", category: "金酒", confidence: "high", introduction: "介绍", flavors: ["柑橘", "草本"], cocktails: [])
    let revision = store.knowledgeRevision
    try store.applyKnowledge(knowledge, to: drink)
    #expect(drink.tasteVariant == "佛手柑" && drink.bottleYear == "2021")
    #expect(drink.collectionDate == date && drink.notes == "手动备注")
    #expect(store.knowledgeRevision > revision)
    #expect(try store.images.loadKnowledge(for: drink.id)?.flavors == ["柑橘", "草本"])
}
