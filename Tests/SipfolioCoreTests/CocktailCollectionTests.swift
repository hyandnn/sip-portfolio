import Foundation
import SwiftData
import Testing
@testable import SipfolioCore

@Test @MainActor
func customCategoriesAndHistorySurviveReopen() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioCategories-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root)
    let image = try testPNG()
    let drink = try store.add(name: "蜂蜜酒", category: " 蜂蜜酒 ", notes: "", original: image, sticker: image, thumbnail: image, usesOriginalPhoto: true)
    #expect(drink.category == "蜂蜜酒")
    try store.update(drink, name: drink.name, category: "干型蜂蜜酒", notes: "")
    let reopened = try CollectionStore(root: root)
    #expect(try reopened.allDrinks().first?.category == "干型蜂蜜酒")
    #expect(CategoryHistory.suggestions(from: ["蜂蜜酒", "金酒", " 蜂蜜酒 ", "", "GIN", "gin"]) == ["蜂蜜酒", "金酒", "GIN"])
    #expect(CategoryHistory.suggestions(from: ["金酒", "蜂蜜酒", "干型蜂蜜酒"], matching: " 蜂蜜 ") == ["蜂蜜酒", "干型蜂蜜酒"])
    try store.update(drink, name: drink.name, category: " ", notes: "")
    #expect(drink.category == "未分类")
}

@Test @MainActor
func cocktailCRUDPersistsAndBottleDeletionKeepsRecipe() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioCocktails-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root)
    let image = try testPNG()
    let drink = try store.add(name: "林德莱姆", category: "金酒", notes: "", original: image, sticker: image, thumbnail: image, usesOriginalPhoto: false, tasteVariant: "佛手柑")
    let recipe = try store.addCocktail(name: " Gin & Tonic ", ingredients: "金酒 — 45 ml\n汤力水 — 120 ml", steps: "加冰后倒入，轻轻搅拌。", glass: "高球杯", garnish: "柠檬片", notes: "少一点汤力水", sourceDrinkID: drink.id, sourceDrinkName: "林德莱姆 · 佛手柑", generatedByAI: true)
    #expect(recipe.name == "Gin & Tonic")
    #expect(throws: CocktailError.self) { try store.addCocktail(name: " ", ingredients: "", steps: "") }
    #expect(throws: CocktailError.self) {
        try store.updateCocktail(recipe, name: "", ingredients: "不应写入", steps: "", glass: "", garnish: "", notes: "", generatedByAI: false)
    }
    #expect(recipe.ingredients.hasPrefix("金酒"))
    try store.updateCocktail(recipe, name: "我的 G&T", ingredients: "金酒 — 50 ml\n汤力水 — 100 ml", steps: "先加冰，再倒入酒和汤力水。", glass: "高球杯", garnish: "佛手柑皮", notes: "手动调整", generatedByAI: true)
    let drinkID = drink.id
    _ = try store.delete(drink)
    let reopened = try CollectionStore(root: root)
    #expect(try reopened.allDrinks().isEmpty)
    let saved = try #require(reopened.allCocktails().first)
    #expect(saved.id == recipe.id && saved.name == "我的 G&T")
    #expect(saved.ingredients.contains("50 ml") && saved.steps.contains("先加冰"))
    #expect(saved.sourceDrinkName == "林德莱姆 · 佛手柑" && saved.sourceDrinkID == drinkID)
    #expect(saved.garnish == "佛手柑皮" && saved.notes == "手动调整" && saved.generatedByAI)
    try reopened.deleteCocktail(saved)
    let finalStore = try CollectionStore(root: root)
    #expect(try finalStore.allCocktails().isEmpty)
}

@Test @MainActor
func bottleOnly030StoreAddsCocktailCollectionWithoutDataLoss() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("Sipfolio030Upgrade-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let id = UUID()
    let date = Date(timeIntervalSince1970: 1_600_000_000)
    do {
        let schema = Schema([Drink.self])
        let configuration = ModelConfiguration(schema: schema, url: root.appendingPathComponent("Sipfolio.store"), cloudKitDatabase: .none)
        let old = try ModelContainer(for: schema, configurations: [configuration])
        old.mainContext.insert(Drink(id: id, name: "旧版蜂蜜酒", category: "蜂蜜酒", notes: "原先的备注", tasteVariant: "经典", bottleYear: "2020", collectionDate: date))
        try old.mainContext.save()
    }
    let current = try CollectionStore(root: root)
    let drink = try #require(current.allDrinks().first)
    #expect(drink.id == id && drink.category == "蜂蜜酒" && drink.notes == "原先的备注")
    #expect(drink.tasteVariant == "经典" && drink.bottleYear == "2020" && drink.collectionDate == date)
    #expect(try current.allCocktails().isEmpty)
    _ = try current.addCocktail(name: "蜂蜜酒加冰", ingredients: "蜂蜜酒 — 60 ml\n冰块 — 适量", steps: "加冰后倒入酒。", sourceDrinkID: id, sourceDrinkName: drink.name)
    let reopened = try CollectionStore(root: root)
    #expect(try reopened.allCocktails().count == 1 && reopened.allDrinks().count == 1)
}
