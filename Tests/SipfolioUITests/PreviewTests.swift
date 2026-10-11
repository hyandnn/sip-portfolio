import Testing
import SwiftUI
import AppKit
import SipfolioCore
import SipfolioTestSupport
@testable import Sipfolio

/// Render repository-owned test views. QA_OUTPUT is output only, never a fixture input.
@MainActor
private func renderPreview(_ name: String, view: AnyView, size: NSSize) async throws {
    let host = NSHostingView(rootView: view.preferredColorScheme(.light))
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
    window.contentView = host
    defer { window.contentView = nil }
    host.frame = NSRect(origin: .zero, size: size)
    host.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(150))
    host.layoutSubtreeIfNeeded()
    let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
    host.cacheDisplay(in: host.bounds, to: bitmap)
    #expect(bitmap.pixelsWide >= Int(size.width))
    #expect(bitmap.pixelsHigh >= Int(size.height))
    if let path = ProcessInfo.processInfo.environment["SIPFOLIO_QA_OUTPUT"] {
        let output = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try #require(bitmap.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent("\(name).png"))
    }
}

@Test @MainActor
func renderMainAndImportLayouts() async throws {
    #expect(PixelTypography.fontName != "Menlo")
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioPreview-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root, inMemory: true)
    let main = CollectionView(store: store, isAdding: .constant(false)).modelContainer(store.container)
    let cocktailMain = CollectionView(store: store, isAdding: .constant(false), initiallyShowingCocktails: true).modelContainer(store.container)
    let suggestion = DrinkKnowledge(name: "Hendrick’s Gin", category: "金酒", confidence: "high", introduction: "以黄瓜和玫瑰为特色的金酒。", flavors: ["杜松子", "黄瓜", "玫瑰"], cocktails: ["Gin & Tonic", "Martini"], uncertainty: "请核对瓶身版本。")
    for (name, view, size) in [
        ("collection-empty", AnyView(main), NSSize(width: 1180, height: 774)),
        ("import-form", AnyView(AddDrinkView(store: store)), NSSize(width: 736, height: 740)),
        ("ai-suggestion", AnyView(AISuggestionView(knowledge: suggestion) { _ in }), NSSize(width: 580, height: 640)),
        ("cocktail-empty", AnyView(cocktailMain), NSSize(width: 1180, height: 774)),
        ("cocktail-new", AnyView(CocktailEditorView(store: store, seed: CocktailSeed(name: "Gin & Tonic", sourceDrinkName: "Hendrick’s Gin", category: "金酒"))), NSSize(width: 700, height: 730))
    ] {
        try await renderPreview(name, view: view, size: size)
    }

    // These populated layouts always run, even in a fresh checkout without QA output.
    // Original-photo fallback avoids making UI tests depend on Vision/Neural Engine.
    let imageService = BottleCutoutService()
    let original = try await imageService.normalizedPNG(from: TestResources.data(named: "hendricks", extension: "jpg"), maxPixelSize: 1200)
    let thumbnail = try await imageService.normalizedPNG(from: original, maxPixelSize: 420)
    let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2024, month: 9, day: 15))!
    let drink = try store.add(name: "Hendrick’s Gin", category: "金酒", notes: "公开照片，仅用于隔离布局测试。", original: original, sticker: original, thumbnail: thumbnail, usesOriginalPhoto: true, knowledge: suggestion, tasteVariant: "经典", bottleYear: "2020", collectionDate: date, includeRecommendedCocktails: false)
    _ = try store.add(name: "无口味／年份的布局示例", category: "蜂蜜酒", notes: "布局验证使用同一张公开图片。", original: original, sticker: original, thumbnail: thumbnail, usesOriginalPhoto: true)
    let recipe = try store.addCocktail(name: "Gin & Tonic", ingredients: "Hendrick’s Gin — 45 ml\n汤力水 — 120 ml\n冰块 — 适量", steps: "1. 高球杯中放入冰块。\n2. 倒入金酒，再加入汤力水。\n3. 轻轻搅拌，放入黄瓜片。", glass: "高球杯", garnish: "黄瓜片", notes: "一杯份量的参考，可按口味调整。", sourceDrinkID: drink.id, sourceDrinkName: "Hendrick’s Gin · 经典", generatedByAI: true)
    let cocktailPhoto = try await imageService.normalizedPNG(from: TestResources.data(named: "gin-tonic", extension: "jpg"), maxPixelSize: 1200)
    let cocktailThumbnail = try await imageService.normalizedPNG(from: cocktailPhoto, maxPixelSize: 420)
    try store.saveCocktailPhoto(id: recipe.id, original: cocktailPhoto, sticker: cocktailPhoto, thumbnail: cocktailThumbnail, metadata: .init(provider: "TheCocktailDB", pageURL: "https://www.thecocktaildb.com/drink/11403", photoSourceURL: "https://pxhere.com/en/photo/1556755", credit: "pxhere.com", creativeCommonsConfirmed: true))
    for (name, view, size) in [
        ("collection-populated", AnyView(main), NSSize(width: 1180, height: 774)),
        ("drink-detail", AnyView(DrinkDetailView(drink: drink, store: store)), NSSize(width: 700, height: 640)),
        ("drink-edit", AnyView(DrinkDetailView(drink: drink, store: store, initiallyEditing: true)), NSSize(width: 700, height: 640)),
        ("cocktail-collection", AnyView(cocktailMain), NSSize(width: 1180, height: 774)),
        ("cocktail-compact", AnyView(cocktailMain), NSSize(width: 960, height: 680)),
        ("cocktail-detail", AnyView(CocktailDetailView(recipe: recipe, store: store)), NSSize(width: 620, height: 660)),
        ("cocktail-edit", AnyView(CocktailEditorView(store: store, recipe: recipe)), NSSize(width: 700, height: 730)),
        ("cocktail-photo", AnyView(CocktailPhotoEditorView(recipeID: recipe.id, store: store)), NSSize(width: 620, height: 600))
    ] {
        try await renderPreview(name, view: view, size: size)
    }
}

private func mockPhotoCandidate(_ index: Int) -> CocktailPhotoCandidate {
    .init(title: "Gin And Tonic · 模拟候选 \(index + 1)", imageURL: URL(string: "https://example.invalid/gin-tonic-\(index).jpg")!, pageURL: URL(string: "https://example.invalid/photos/\(index)")!, credit: "pxhere.com（布局素材）", license: "CC0", licenseURL: URL(string: "https://creativecommons.org/publicdomain/zero/1.0/")!, origin: index < 2 ? .commons : .openverseCommons)
}

@Test @MainActor
func renderCocktailPhotoCandidateLayout() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioPhotoPreview-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root, inMemory: true)
    let recipe = try store.addCocktail(name: "Gin And Tonic", ingredients: "金酒 — 45 ml\n汤力水 — 120 ml", steps: "加冰后轻轻搅拌。")
    let candidates = (0..<4).map(mockPhotoCandidate)
    let image = try TestResources.data(named: "gin-tonic", extension: "jpg")
    let previews = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, image) })
    try await renderPreview("cocktail-photo-search", view: AnyView(CocktailPhotoSearchView(recipeID: recipe.id, recipeName: recipe.name, store: store, candidates: candidates, previews: previews)), size: NSSize(width: 740, height: 710))
}

@Test @MainActor
func renderCollectionBooksAndFullPhotoPreview() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioBooksPreview-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root, inMemory: true)
    let ginTonic = try store.addCocktail(name: "Gin And Tonic", ingredients: "金酒 — 45 ml\n汤力水 — 120 ml", steps: "加冰后轻轻搅拌。", glass: "高球杯")
    _ = try store.addCocktail(name: "纸飞机", ingredients: "波本威士忌 — 30 ml\n柠檬汁 — 30 ml", steps: "摇和后滤入杯中。", glass: "碟形杯")
    _ = try store.addCocktail(name: "我的文字配方", ingredients: "蜂蜜酒 — 60 ml\n冰块 — 适量", steps: "倒入冰杯，轻轻搅拌。")
    let photo = try TestResources.data(named: "gin-tonic", extension: "jpg")
    try store.saveCocktailPhoto(id: ginTonic.id, original: photo, sticker: photo, thumbnail: photo, metadata: .init(provider: "TheCocktailDB", pageURL: "https://www.thecocktaildb.com/drink/11403", photoSourceURL: "https://pxhere.com/en/photo/1556755", credit: "pxhere.com", creativeCommonsConfirmed: true))
    for (name, view, size) in [
        ("cocktail-photo-book-compact", AnyView(CollectionView(store: store, isAdding: .constant(false), initiallyShowingCocktails: true).modelContainer(store.container)), NSSize(width: 960, height: 680)),
        ("cocktail-text-compact", AnyView(CollectionView(store: store, isAdding: .constant(false), initiallyShowingCocktails: true, initialCocktailBook: .text).modelContainer(store.container)), NSSize(width: 960, height: 680)),
        ("cocktail-text-collection", AnyView(CollectionView(store: store, isAdding: .constant(false), initiallyShowingCocktails: true, initialCocktailBook: .text).modelContainer(store.container)), NSSize(width: 1180, height: 774)),
        ("cocktail-search-alias", AnyView(CollectionView(store: store, isAdding: .constant(false), initiallyShowingCocktails: true, initialSearch: "金汤力").modelContainer(store.container)), NSSize(width: 960, height: 680)),
        ("cocktail-photo-full-preview", AnyView(CocktailCandidatePreview(candidate: mockPhotoCandidate(0), data: photo) {}), NSSize(width: 650, height: 600))
    ] {
        try await renderPreview(name, view: view, size: size)
    }
}
