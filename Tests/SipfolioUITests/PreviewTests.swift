import Testing
import SwiftUI
import AppKit
import SipfolioCore
@testable import Sipfolio

@Test @MainActor
func renderMainAndImportLayouts() async throws {
    #expect(PixelTypography.fontName != "Menlo")
    // Render our own views offscreen, without reading or controlling a user's app window.
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioPreview-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root, inMemory: true)
    let main = CollectionView(store: store, isAdding: .constant(false))
        .modelContainer(store.container).frame(width: 1180, height: 774).preferredColorScheme(.light)
    let form = AddDrinkView(store: store).preferredColorScheme(.light)
    let cocktailMain = CollectionView(store: store, isAdding: .constant(false), initiallyShowingCocktails: true)
        .modelContainer(store.container).frame(width: 1180, height: 774).preferredColorScheme(.light)
    var suggestion = DrinkKnowledge(name: "Hendrick’s Gin", category: "金酒", confidence: "high", introduction: "以黄瓜和玫瑰为特色的金酒。", flavors: ["杜松子", "黄瓜", "玫瑰"], cocktails: ["Gin & Tonic", "Martini"], uncertainty: "请核对瓶身版本。")
    if let path = ProcessInfo.processInfo.environment["SIPFOLIO_QA_OUTPUT"] {
        let response = URL(fileURLWithPath: path).appendingPathComponent("deepseek-live-result.json")
        if let data = try? Data(contentsOf: response), let live = try? JSONDecoder().decode(DrinkKnowledge.self, from: data) { suggestion = live }
    }
    for (name, view, size) in [
        ("collection-empty", AnyView(main), NSSize(width: 1180, height: 774)),
        ("import-form", AnyView(form), NSSize(width: 736, height: 740)),
        ("ai-suggestion", AnyView(AISuggestionView(knowledge: suggestion) { _ in }), NSSize(width: 580, height: 640)),
        ("cocktail-empty", AnyView(cocktailMain), NSSize(width: 1180, height: 774)),
        ("cocktail-new", AnyView(CocktailEditorView(store: store, seed: CocktailSeed(name: "Gin & Tonic", sourceDrinkName: "Hendrick’s Gin", category: "金酒"))), NSSize(width: 700, height: 730))
    ] {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        #expect(bitmap.pixelsWide >= Int(size.width))
        #expect(bitmap.pixelsHigh >= Int(size.height))
        if let path = ProcessInfo.processInfo.environment["SIPFOLIO_QA_OUTPUT"] {
            let output = URL(fileURLWithPath: path, isDirectory: true)
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: output.appendingPathComponent("\(name).png"))
        }
    }
    if let path = ProcessInfo.processInfo.environment["SIPFOLIO_QA_OUTPUT"] {
        let output = URL(fileURLWithPath: path, isDirectory: true)
        let stickerURL = output.appendingPathComponent("bottle-sticker.png")
        let originalURL = output.appendingPathComponent("bottle-original.png")
        if FileManager.default.fileExists(atPath: stickerURL.path), FileManager.default.fileExists(atPath: originalURL.path) {
            let sticker = try Data(contentsOf: stickerURL)
            let original = try Data(contentsOf: originalURL)
            let thumbnail = try await BottleCutoutService().normalizedPNG(from: sticker, maxPixelSize: 420)
            let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2024, month: 9, day: 15))!
            let drink = try store.add(name: "Hendrick’s Gin", category: "金酒", notes: "用于开发验证的公开照片。\n酒瓶变成一枚白色描边的贴纸，收进个人图鉴。", original: original, sticker: sticker, thumbnail: thumbnail, usesOriginalPhoto: false, knowledge: suggestion, tasteVariant: "经典", bottleYear: "2020", collectionDate: date, includeRecommendedCocktails: false)
            _ = try store.add(name: "无口味／年份的布局示例", category: "蜂蜜酒", notes: "布局验证使用同一张公开图片。", original: original, sticker: sticker, thumbnail: thumbnail, usesOriginalPhoto: false)
            let recipe = try store.addCocktail(name: "Gin & Tonic", ingredients: "Hendrick’s Gin — 45 ml\n汤力水 — 120 ml\n冰块 — 适量", steps: "1. 高球杯中放入冰块。\n2. 倒入金酒，再加入汤力水。\n3. 轻轻搅拌，放入黄瓜片。", glass: "高球杯", garnish: "黄瓜片", notes: "一杯份量的参考比例，可按口味调整。", sourceDrinkID: drink.id, sourceDrinkName: "Hendrick’s Gin · 经典", generatedByAI: true)
            let cocktailStickerURL = output.appendingPathComponent("cocktail-gin-tonic-sticker.png")
            let cocktailOriginalURL = output.appendingPathComponent("cocktail-gin-tonic-original.png")
            if let cocktailSticker = try? Data(contentsOf: cocktailStickerURL), let cocktailOriginal = try? Data(contentsOf: cocktailOriginalURL) {
                let cocktailThumbnail = try await BottleCutoutService().normalizedPNG(from: cocktailSticker, maxPixelSize: 420)
                try store.saveCocktailPhoto(id: recipe.id, original: cocktailOriginal, sticker: cocktailSticker, thumbnail: cocktailThumbnail, metadata: CocktailPhotoMetadata(provider: "TheCocktailDB", pageURL: "https://www.thecocktaildb.com/drink/11403", photoSourceURL: "https://pxhere.com/en/photo/1556755", credit: "pxhere.com", creativeCommonsConfirmed: true))
            }
            for (name, view, size) in [
                ("collection-populated", AnyView(main), NSSize(width: 1180, height: 774)),
                ("drink-detail", AnyView(DrinkDetailView(drink: drink, store: store)), NSSize(width: 700, height: 640)),
                ("drink-edit", AnyView(DrinkDetailView(drink: drink, store: store, initiallyEditing: true)), NSSize(width: 700, height: 640)),
                ("cocktail-collection", AnyView(cocktailMain), NSSize(width: 1180, height: 774)),
                ("cocktail-compact", AnyView(CollectionView(store: store, isAdding: .constant(false), initiallyShowingCocktails: true).modelContainer(store.container).frame(width: 960, height: 680).preferredColorScheme(.light)), NSSize(width: 960, height: 680)),
                ("cocktail-detail", AnyView(CocktailDetailView(recipe: recipe, store: store)), NSSize(width: 620, height: 660)),
                ("cocktail-edit", AnyView(CocktailEditorView(store: store, recipe: recipe)), NSSize(width: 700, height: 730)),
                ("cocktail-photo", AnyView(CocktailPhotoEditorView(recipeID: recipe.id, store: store)), NSSize(width: 620, height: 600))
            ] {
                let host = NSHostingView(rootView: view)
                let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
                window.contentView = host
                host.frame = NSRect(origin: .zero, size: size)
                host.layoutSubtreeIfNeeded()
                try await Task.sleep(for: .milliseconds(150))
                host.layoutSubtreeIfNeeded()
                let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: output.appendingPathComponent("\(name).png"))
                window.contentView = nil
            }
        }
    }
}
