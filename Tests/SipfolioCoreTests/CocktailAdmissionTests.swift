import SipfolioTestSupport
import Testing
import Foundation
@testable import SipfolioCore

@Test
func recipeAdmissionRequiresIngredientsAndInstructions() {
    #expect(!CocktailAdmission.accepts(ingredients: "", steps: ""))
    #expect(CocktailAdmission.accepts(ingredients: "金酒\n汤力水", steps: "搅拌"))
    #expect(!CocktailAdmission.accepts(ingredients: "45 ml", steps: "搅拌"))
    #expect(!CocktailAdmission.accepts(ingredients: "金酒 — 45 ml", steps: " \n"))
    #expect(!CocktailAdmission.accepts(ingredients: "金酒 — 45 ml", steps: "待补充"))
    #expect(!CocktailAdmission.accepts(ingredients: "金酒 — 45 ml", steps: "1. \n"))
    #expect(CocktailAdmission.accepts(ingredients: "金酒 — 来源未注明用量", steps: "搅拌"))
    #expect(CocktailAdmission.accepts(ingredients: "金酒 — 45 ml\n汤力水 — 120 ml\n冰块 — 适量\n青柠 — 1", steps: "加冰后倒入，轻轻搅拌。"))
    #expect(CocktailAdmission.accepts(ingredients: "Gin — 1 2/3 oz\nLemon — 1/2 slice", steps: "Stir."))
    #expect(CocktailAdmission.accepts(ingredients: "金酒 — 1 份\n汤力水 — 3 份", steps: "加冰混合。"))
}

@Test
func publicRecipeFruitAndCountMeasuresAreUsable() {
    let examples = [
        "淡朗姆酒 — 1 1/2 oz\n青柠 — Juice of 1/2\nPowdered sugar — 1 tsp",
        "Blended whiskey — 2 oz\n柠檬 — Juice of 1/2\nPowdered sugar — 1/2 tsp\nCherry — 1\n柠檬 — 1/2 slice",
        "Bourbon — 4.5 cL\nAngostura bitters — 2 dashes\n糖 — 1 cube\nWater — dash"
    ]
    for ingredients in examples {
        #expect(CocktailAdmission.accepts(ingredients: ingredients, steps: "按原配方调制。"))
        let items = ingredients.split(separator: "\n").map { line in
            let parts = line.components(separatedBy: " — ")
            return CocktailSuggestion.Ingredient(name: parts[0], amount: parts[1])
        }
        let suggestion = CocktailSuggestion(name: "公开参考配方", ingredients: items, steps: ["按原配方调制。"], glass: "", garnish: "", notes: "")
        #expect(CocktailAdmission.accepts(suggestion))
    }
    #expect(CocktailAdmission.accepts(ingredients: "龙舌兰酒 — 2 measures\nOrange juice — 来源未注明用量\nGrenadine — 来源未注明用量", steps: "混合。"))
}

@Test @MainActor
func manualRecipesCannotSaveMissingIngredientsOrSteps() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioAdmission-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root, inMemory: true)
    #expect(throws: CocktailError.incompleteRecipe) { try store.addCocktail(name: "Highball", ingredients: "", steps: "加苏打水") }
    #expect(throws: CocktailError.incompleteRecipe) { try store.addCocktail(name: "Highball", ingredients: "威士忌 — 45 ml", steps: "") }
    #expect(try store.allCocktails().isEmpty)
    let recipe = try store.addCocktail(name: "Highball", ingredients: "威士忌 — 45 ml\n苏打水 — 135 ml", steps: "加冰，倒入威士忌与苏打水，轻轻搅拌。")
    #expect(throws: CocktailError.incompleteRecipe) { try store.updateCocktail(recipe, name: "改名", ingredients: "威士忌", steps: "", glass: "", garnish: "", notes: "", generatedByAI: false) }
    #expect(recipe.name == "Highball" && recipe.ingredients.contains("45 ml"))
}

private actor AdmissionTransport: AIHTTPTransport {
    let reference: Data
    var requests: [URLRequest] = []
    init(reference: Data) { self.reference = reference }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        return (reference, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
    func allRequests() -> [URLRequest] { requests }
}

@Test @MainActor
func rejectedRecommendationsNeverEnterCollectionOrRequestPhotos() async throws {
    for response in [Data("{\"drinks\":null}".utf8), Data(#"{"drinks":[{"idDrink":"1","strDrink":"Unknown","strIngredient1":"Gin","strInstructions":"","strDrinkThumb":"https://www.thecocktaildb.com/images/media/drink/test.jpg"}]}"#.utf8)] {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioRejected-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try CollectionStore(root: root)
        let image = try testPNG()
        let knowledge = DrinkKnowledge(name: "金酒", category: "金酒", confidence: "high", introduction: "", flavors: [], cocktails: ["Unknown"])
        _ = try store.add(name: "金酒", category: "金酒", notes: "私人备注", original: image, sticker: image, thumbnail: image, usesOriginalPhoto: true, knowledge: knowledge)
        #expect(try store.allCocktails().isEmpty)
        let transport = AdmissionTransport(reference: response)
        let coordinator = CocktailEnrichmentCoordinator(store: store, referenceService: .init(transport: transport), photoService: .init(transport: transport))
        coordinator.startPending()
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while coordinator.isWorking, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
        #expect(!coordinator.isWorking)
        #expect(try store.allCocktails().isEmpty && store.pendingRecommendations.isEmpty)
        let requests = await transport.allRequests()
        #expect(requests.count == 1 && requests.first?.url?.path.hasSuffix("search.php") == true)
        #expect(requests.first?.httpBody == nil)
        #expect(!FileManager.default.fileExists(atPath: store.cocktailImages.root.path))
    }
}

@Test @MainActor
func recommendationQueueSurvivesRestartAndPhotoBooksFollowMedia() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioQueued-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let image = try testPNG()
    do {
        let store = try CollectionStore(root: root)
        let knowledge = DrinkKnowledge(name: "金酒", category: "金酒", confidence: "high", introduction: "", flavors: [], cocktails: ["Gin & Tonic"])
        _ = try store.add(name: "金酒", category: "金酒", notes: "", original: image, sticker: image, thumbnail: image, usesOriginalPhoto: true, knowledge: knowledge)
        #expect(store.pendingRecommendations.count == 1)
        #expect(try store.allCocktails().isEmpty)
    }
    let reopened = try CollectionStore(root: root)
    #expect(reopened.pendingRecommendations.count == 1)
    let fixture = try Data(contentsOf: #require(TestResources.url(forResource: "gin-tonic-reference", withExtension: "json")))
    let reference = try CocktailReferenceService.decode(fixture, matching: "金汤力")
    let recipe = try #require(try reopened.admitRecommendation(CocktailNames.key("Gin & Tonic"), reference: reference))
    #expect(CocktailCollectionBook.text.includes(hasPhoto: false))
    #expect(!CocktailCollectionBook.photos.includes(hasPhoto: false))
    try reopened.saveCocktailPhoto(id: recipe.id, original: image, sticker: image, thumbnail: image, metadata: .init(provider: "自己的照片"))
    let hasPhoto = FileManager.default.fileExists(atPath: reopened.cocktailImages.imageURL(for: recipe.id, original: true).path)
    #expect(CocktailCollectionBook.photos.includes(hasPhoto: hasPhoto) && !CocktailCollectionBook.text.includes(hasPhoto: hasPhoto))
    #expect(reopened.pendingRecommendations.isEmpty)
}

@Test @MainActor
func legacyIncompleteRecipesLeaveCollectionWithRecoveryCopy() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioLegacyIncomplete-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root)
    let incomplete = CocktailRecipe(name: "金汤力", notes: "原来的备注", sourceDrinkID: UUID(), sourceDrinkName: "曾经的酒瓶")
    store.container.mainContext.insert(incomplete)
    try store.container.mainContext.save()
    let image = try testPNG()
    try store.saveCocktailPhoto(id: incomplete.id, original: image, sticker: image, thumbnail: image, metadata: .init(provider: "自己的照片"))
    let valid = try store.addCocktail(name: "自己的完整配方", ingredients: "金酒 — 45 ml", steps: "加冰搅拌。", notes: "手动备注")
    try store.archiveIncompleteCocktails()
    try store.archiveIncompleteCocktails()
    #expect(try store.allCocktails().map(\.id) == [valid.id])
    let archive = try JSONDecoder().decode([ArchivedCocktailRecipe].self, from: Data(contentsOf: root.appendingPathComponent("incomplete-recipes-archive.json")))
    #expect(archive.count == 1 && archive.first?.notes == "原来的备注")
    #expect(try Data(contentsOf: store.cocktailImages.imageURL(for: incomplete.id, original: true)) == image)
    #expect(store.pendingRecommendations.count == 1)
    let fixture = try Data(contentsOf: #require(TestResources.url(forResource: "gin-tonic-reference", withExtension: "json")))
    let reference = try CocktailReferenceService.decode(fixture, matching: "金汤力")
    let restored = try #require(try store.admitRecommendation(CocktailNames.key("金汤力"), reference: reference))
    #expect(restored.id == incomplete.id && restored.notes == "原来的备注")
    #expect(try store.cocktailPhotoMetadata(for: restored.id)?.provider == "自己的照片")
}

@Test @MainActor
func previouslyArchivedReferenceMeasuresRestoreOnceAndKeepPhotos() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioReferenceRecovery-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root)
    let original = CocktailRecipe(name: "Daiquiri", ingredients: "淡朗姆酒 — 1 1/2 oz\n青柠 — Juice of 1/2", steps: "摇匀后滤入冷杯。", notes: "手动备注", sourceDrinkID: UUID(), sourceDrinkName: "已关联酒瓶")
    let id = original.id
    store.container.mainContext.insert(original); try store.container.mainContext.save()
    let image = try testPNG()
    try store.saveCocktailPhoto(id: id, original: image, sticker: image, thumbnail: image, metadata: .init(provider: "自己的照片"))
    let archive = [ArchivedCocktailRecipe(original), ArchivedCocktailRecipe(CocktailRecipe(name: "只有名字"))]
    try JSONEncoder().encode(archive).write(to: root.appendingPathComponent("incomplete-recipes-archive.json"))
    store.container.mainContext.delete(original); try store.container.mainContext.save()
    try store.restoreUsableArchivedCocktails()
    let restored = try #require(store.allCocktails().first)
    #expect(restored.id == id && restored.notes == "手动备注" && restored.ingredients.contains("Juice of 1/2"))
    #expect(try store.cocktailPhotoMetadata(for: id)?.provider == "自己的照片")
    try store.restoreUsableArchivedCocktails()
    #expect(try store.allCocktails().count == 1)
    try store.deleteCocktail(restored)
    try store.restoreUsableArchivedCocktails()
    #expect(try store.allCocktails().isEmpty)
}
