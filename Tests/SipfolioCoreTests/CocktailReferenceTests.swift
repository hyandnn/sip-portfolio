import Testing
import Foundation
import ImageIO
import SwiftData
@testable import SipfolioCore

private func referenceFixture() throws -> Data {
    let path = Bundle.module.url(forResource: "gin-tonic-reference", withExtension: "json", subdirectory: "Fixtures")!
    return try Data(contentsOf: path)
}

private actor ReferenceTransport: AIHTTPTransport {
    let data: Data
    var requests: [URLRequest] = []
    init(_ data: Data) { self.data = data }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
    func request() -> URLRequest? { requests.first }
}

@Test
func publicRecipeLookupKeepsMeasuresAndImageAttribution() async throws {
    let transport = ReferenceTransport(try referenceFixture())
    let reference = try await CocktailReferenceService(transport: transport).lookup(name: "金汤力")
    #expect(reference.suggestion.ingredients[0] == .init(name: "金酒", amount: "2 oz"))
    #expect(reference.suggestion.ingredients[1] == .init(name: "汤力水", amount: "5 oz"))
    #expect(reference.suggestion.stepsText.contains("高球杯"))
    #expect(reference.photoCredit == "pxhere.com" && reference.creativeCommonsConfirmed)
    #expect(reference.pageURL.absoluteString == "https://www.thecocktaildb.com/drink/11403")
    let request = try #require(await transport.request())
    #expect(request.url?.host == "www.thecocktaildb.com")
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value == "Gin and Tonic")
}

@Test
func wrongRecipesAndUntrustedPhotoURLsAreRejected() async throws {
    #expect(throws: CocktailReferenceError.notFound) { try CocktailReferenceService.decode(referenceFixture(), matching: "Martini") }
    #expect(throws: CocktailReferenceError.notFound) { try CocktailReferenceService.decode(Data("{\"drinks\":null}".utf8), matching: "Unknown") }
    #expect(CocktailNames.key("Gin & Tonic（加青柠）") == CocktailNames.key("金汤力"))
    #expect(CocktailNames.key("Negroni Sbagliato") != CocktailNames.key("Negroni"))
    let service = CocktailReferenceService(transport: ReferenceTransport(Data()))
    await #expect(throws: CocktailReferenceError.invalidImageURL) { try await service.downloadPhoto(URL(string: "https://example.com/private")!) }
}

@Test
func officialPhotoAvailabilityDoesNotDependOnCCConfirmation() throws {
    let path = try #require(Bundle.module.url(forResource: "martini-reference", withExtension: "json", subdirectory: "Fixtures"))
    let data = try Data(contentsOf: path)
    let reference = try CocktailReferenceService.decode(data, matching: "Martini")
    #expect(reference.photoURL?.absoluteString == "https://www.thecocktaildb.com/images/media/drink/71t8581504353095.jpg")
    #expect(!reference.creativeCommonsConfirmed)
    #expect(reference.pageURL.absoluteString == "https://www.thecocktaildb.com/drink/11728")
    var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    var drinks = try #require(object["drinks"] as? [[String: Any]])
    drinks[0]["strCreativeCommonsConfirmed"] = NSNull()
    object["drinks"] = drinks
    let withoutConfirmation = try CocktailReferenceService.decode(JSONSerialization.data(withJSONObject: object), matching: "Martini")
    #expect(withoutConfirmation.photoURL == reference.photoURL)
    #expect(!withoutConfirmation.creativeCommonsConfirmed)
    for url in ["", "http://www.thecocktaildb.com/images/media/drink/test.jpg", "https://example.com/image.jpg"] {
        drinks[0]["strDrinkThumb"] = url; object["drinks"] = drinks
        let invalid = try CocktailReferenceService.decode(JSONSerialization.data(withJSONObject: object), matching: "Martini")
        #expect(invalid.photoURL == nil)
    }
}

@Test @MainActor
func automaticRecommendationsMergeBottleSourcesAndRespectOptOut() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioAutoRecipes-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root)
    let image = try testPNG()
    let knowledge = DrinkKnowledge(name: "测试金酒", category: "金酒", confidence: "high", introduction: "", flavors: [], cocktails: ["Gin & Tonic", "金汤力", "Martini"])
    let first = try store.add(name: "第一瓶", category: "金酒", notes: "", original: image, sticker: image, thumbnail: image, usesOriginalPhoto: true, knowledge: knowledge)
    #expect(try store.allCocktails().count == 2)
    let gt = try #require(store.allCocktails().first { CocktailNames.key($0.name) == CocktailNames.key("金汤力") })
    try store.updateCocktail(gt, name: gt.name, ingredients: "我的手动比例", steps: "手动步骤", glass: "", garnish: "", notes: "我的备注", generatedByAI: false)
    let second = try store.add(name: "第二瓶", category: "金酒", notes: "", original: image, sticker: image, thumbnail: image, usesOriginalPhoto: true, knowledge: knowledge)
    #expect(gt.linkedSources.map(\.id) == [first.id, second.id])
    #expect(gt.ingredients == "我的手动比例" && gt.notes == "我的备注")
    _ = try store.collectRecommendations(knowledge, for: second)
    #expect(gt.linkedSources.count == 2)
    #expect(try store.allCocktails().count == 2)
    _ = try store.add(name: "第三瓶", category: "金酒", notes: "", original: image, sticker: image, thumbnail: image, usesOriginalPhoto: true, knowledge: DrinkKnowledge(name: "第三瓶", category: "金酒", confidence: "high", introduction: "", flavors: [], cocktails: ["Mojito"]), includeRecommendedCocktails: false)
    #expect(try store.allCocktails().count == 2)
    let reopened = try CollectionStore(root: root)
    #expect(try reopened.allCocktails().first { $0.id == gt.id }?.linkedSources.count == 2)
}

@Test @MainActor
func mediaAndReferencePersistWithoutReplacingUserRecipe() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioRecipeMedia-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root)
    let recipe = try store.addCocktail(name: "Gin & Tonic", ingredients: "手动材料", steps: "我的步骤", glass: "", notes: "私人备注")
    let reference = try CocktailReferenceService.decode(referenceFixture(), matching: recipe.name)
    try store.applyReference(reference, to: recipe.id)
    #expect(recipe.ingredients == "手动材料" && recipe.steps == "我的步骤" && recipe.notes == "私人备注")
    #expect(recipe.glass == "高球杯")
    let image = try testPNG()
    let info = CocktailPhotoMetadata(provider: "TheCocktailDB", pageURL: reference.pageURL.absoluteString, credit: reference.photoCredit, creativeCommonsConfirmed: true)
    try store.saveCocktailPhoto(id: recipe.id, original: image, sticker: image, thumbnail: image, metadata: info)
    let replaced = CocktailPhotoMetadata(provider: "自己的照片", usesOriginalPhoto: true)
    try store.saveCocktailPhoto(id: recipe.id, original: image, sticker: image, thumbnail: image, metadata: replaced)
    let reopened = try CollectionStore(root: root)
    let saved = try #require(reopened.allCocktails().first)
    #expect(saved.referenceProvider == "TheCocktailDB")
    #expect(try reopened.cocktailPhotoMetadata(for: saved.id) == replaced)
    #expect(try Data(contentsOf: reopened.cocktailImages.imageURL(for: saved.id)) == image)
    let id = saved.id
    try reopened.deleteCocktail(saved)
    #expect(!FileManager.default.fileExists(atPath: reopened.cocktailImages.directory(for: id).path))
}

private actor PhotoReferenceTransport: AIHTTPTransport {
    let reference: Data
    let photo: Data
    init(reference: Data, photo: Data) { self.reference = reference; self.photo = photo }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data = request.url!.path.hasPrefix("/images/") ? photo : reference
        return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

@Test @MainActor
func cocktailEnrichmentKeepsTheRealPhotoBackground() async throws {
    let path = Bundle.module.url(forResource: "gin-tonic", withExtension: "jpg", subdirectory: "Fixtures")!
    let sourcePhoto = try Data(contentsOf: path)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioOriginalCocktail-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root)
    let recipe = try store.addCocktail(name: "Gin & Tonic", ingredients: "", steps: "")
    let transport = PhotoReferenceTransport(reference: try referenceFixture(), photo: sourcePhoto)
    let coordinator = CocktailEnrichmentCoordinator(store: store, referenceService: CocktailReferenceService(transport: transport))
    coordinator.startPending()
    let deadline = ContinuousClock.now.advanced(by: .seconds(10))
    while !coordinator.activeIDs.isEmpty, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(40)) }
    #expect(coordinator.activeIDs.isEmpty)
    #expect(coordinator.errors.isEmpty)
    #expect(!recipe.ingredients.isEmpty && !recipe.steps.isEmpty)
    let metadata = try #require(try store.cocktailPhotoMetadata(for: recipe.id))
    #expect(metadata.usesOriginalPhoto && metadata.provider == "TheCocktailDB")
    let original = try Data(contentsOf: store.cocktailImages.imageURL(for: recipe.id, original: true))
    #expect(try Data(contentsOf: store.cocktailImages.imageURL(for: recipe.id)) == original)
    let imageSource = try #require(CGImageSourceCreateWithData(original as CFData, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(imageSource, 0, nil))
    let source = try #require(CGImageSourceCreateWithData(sourcePhoto as CFData, nil))
    let sourceImage = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(image.width == sourceImage.width && image.height == sourceImage.height)
    let context = try #require(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let pixels = try #require(context.data?.assumingMemoryBound(to: UInt8.self))
    var transparent = 0
    for index in 0..<(image.width * image.height) {
        if pixels[index * 4 + 3] < 255 { transparent += 1 }
    }
    #expect(transparent == 0)
    let thumbnail = try Data(contentsOf: store.cocktailImages.thumbnailURL(for: recipe.id))
    let thumbSource = try #require(CGImageSourceCreateWithData(thumbnail as CFData, nil))
    let thumbImage = try #require(CGImageSourceCreateImageAtIndex(thumbSource, 0, nil))
    #expect(max(thumbImage.width, thumbImage.height) == 420)
    if let directory = ProcessInfo.processInfo.environment["SIPFOLIO_QA_OUTPUT"] {
        let output = URL(fileURLWithPath: directory)
        try original.write(to: output.appendingPathComponent("cocktail-gin-tonic-original.png"))
        try thumbnail.write(to: output.appendingPathComponent("cocktail-gin-tonic-thumbnail.png"))
    }
}

private enum LegacyRecipe040 {
    @Model final class CocktailRecipe {
        @Attribute(.unique) var id: UUID
        var name: String
        var ingredients: String
        var steps: String
        var glass: String
        var garnish: String
        var notes: String
        var createdAt: Date
        var sourceDrinkID: UUID?
        var sourceDrinkName: String?
        var generatedByAI: Bool
        init(id: UUID, source: UUID) {
            self.id = id; name = "Martini"; ingredients = "旧版手动材料"; steps = "旧版步骤"
            glass = "鸡尾酒杯"; garnish = "橄榄"; notes = "旧版备注"; createdAt = Date(timeIntervalSince1970: 1_700_000_000)
            sourceDrinkID = source; sourceDrinkName = "旧版金酒"; generatedByAI = false
        }
    }
}

@Test @MainActor
func version040RecipesMigrateWithTheirExistingBottleLinks() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("Sipfolio040Migration-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let id = UUID(), bottleID = UUID()
    do {
        let schema = Schema([Drink.self, LegacyRecipe040.CocktailRecipe.self])
        let config = ModelConfiguration(schema: schema, url: root.appendingPathComponent("Sipfolio.store"), cloudKitDatabase: .none)
        let old = try ModelContainer(for: schema, configurations: [config])
        old.mainContext.insert(LegacyRecipe040.CocktailRecipe(id: id, source: bottleID))
        try old.mainContext.save()
    }
    let current = try CollectionStore(root: root)
    let recipe = try #require(current.allCocktails().first)
    #expect(recipe.id == id && recipe.ingredients == "旧版手动材料" && recipe.notes == "旧版备注")
    #expect(recipe.sourcesJSON == nil && recipe.referenceURL == nil && recipe.referenceProvider == nil)
    #expect(recipe.linkedSources == [CocktailBottleSource(id: bottleID, name: "旧版金酒")])
    let reopened = try CollectionStore(root: root)
    #expect(try reopened.allCocktails().count == 1)
}
