import SipfolioTestSupport
import Testing
import Foundation
@testable import SipfolioCore

private let commonsImage = "https://upload.wikimedia.org/wikipedia/commons/a/ab/Paper_Plane.jpg"
private let commonsPage = "https://commons.wikimedia.org/wiki/File:Paper_Plane.jpg"

private func commonsFixture(license: String = "https://creativecommons.org/licenses/by/4.0/", mime: String = "image/jpeg", image: String = commonsImage, name: String = "Paper Plane") throws -> Data {
    try JSONSerialization.data(withJSONObject: ["query": ["pages": [["title": "File:\(name.replacingOccurrences(of: " ", with: "_")).jpg", "index": 1, "imageinfo": [[
        "url": image, "descriptionurl": commonsPage, "thumburl": "https://thumb.wikimedia.org/wikipedia/commons/thumb/a/ab/Paper_Plane.jpg/640px-Paper_Plane.jpg",
        "width": 1024, "height": 768, "size": 12345, "mime": mime,
        "extmetadata": ["Artist": ["value": "<a href='example'>Photo Author</a>"], "LicenseUrl": ["value": license], "ImageDescription": ["value": "\(name) cocktail"]]
    ]]]]]])
}

private func openverseFixture(source: String = "flickr", license: String = "https://creativecommons.org/licenses/by/2.0/") throws -> Data {
    try JSONSerialization.data(withJSONObject: ["results": [[
        "title": "Paper Plane", "url": "https://live.staticflickr.com/65535/51346964007_e20a3986d4_b.jpg",
        "foreign_landing_url": "https://www.flickr.com/photos/7633518@N08/51346964007", "creator": "Indexed Author",
        "license_url": license, "width": 1024, "height": 768, "mature": false, "source": source
    ]]])
}

private func flickrFixture(license: String = "https://creativecommons.org/publicdomain/zero/1.0/", photoID: String = "51346964007") throws -> Data {
    let json = try JSONSerialization.data(withJSONObject: ["@graph": [["@type": "ImageObject", "license": license,
        "contentUrl": "https://live.staticflickr.com/65535/\(photoID)_e20a3986d4_b.jpg",
        "acquireLicensePage": "https://www.flickr.com/photos/renamed-owner/\(photoID)", "author": ["name": "Current Author"]]]])
    return Data(("<script type=\"application/ld+json\">" + String(decoding: json, as: UTF8.self) + "</script>").utf8)
}

private actor PhotoTransport: AIHTTPTransport {
    var requests: [URLRequest] = []
    let commons: Data
    let openverse: Data
    let image: Data
    let flickr: Data
    let commonsStatus: Int
    let openverseStatus: Int
    let reference: Data
    let officialPhotoStatus: Int
    init(commons: Data = Data("{}".utf8), openverse: Data = Data("{\"results\":[]}".utf8), image: Data = Data(), flickr: Data = Data(), commonsStatus: Int = 200, openverseStatus: Int = 200, reference: Data = Data("{\"drinks\":null}".utf8), officialPhotoStatus: Int = 200) {
        self.commons = commons; self.openverse = openverse; self.image = image; self.flickr = flickr
        self.commonsStatus = commonsStatus; self.openverseStatus = openverseStatus; self.reference = reference; self.officialPhotoStatus = officialPhotoStatus
    }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let url = request.url!
        let data: Data, status: Int
        switch url.host {
        case "commons.wikimedia.org": data = commons; status = commonsStatus
        case "api.openverse.org": data = openverse; status = openverseStatus
        case "www.flickr.com": data = flickr; status = 200
        case "www.thecocktaildb.com":
            if url.path.hasPrefix("/images/") { data = image; status = officialPhotoStatus }
            else { data = reference; status = 200 }
        default: data = image; status = 200
        }
        return (data, HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
    func allRequests() -> [URLRequest] { requests }
}

@Test func cocktailAliasesKeepExplicitVariantsSeparate() {
    for (name, expected) in [("纸飞机", "Paper Plane"), ("法式 75", "French 75"), ("G&T", "Gin and Tonic"), ("gin-tonic", "Gin and Tonic"), ("Piña Colada", "Pina Colada"), ("莫斯科骡子", "Moscow Mule"), ("Bee’s Knees", "Bee's Knees")] {
        #expect(CocktailNames.lookupName(name) == expected)
    }
    #expect(CocktailNames.key("Espresso Martini") != CocktailNames.key("Martini"))
    #expect(CocktailNames.key("草莓莫吉托") != CocktailNames.key("莫吉托"))
    #expect(CocktailNames.key("Ramos Gin Fizz") != CocktailNames.key("Gin Fizz"))
    #expect(CocktailNames.key("Negroni Sbagliato") != CocktailNames.key("Negroni"))
    #expect(CocktailNames.key("Martini（浓缩咖啡）") != CocktailNames.key("Martini"))
    #expect(CocktailNames.key("Negroni (Sbagliato)") != CocktailNames.key("Negroni"))
    #expect(CocktailNames.key("莫吉托（草莓）") != CocktailNames.key("莫吉托"))
    #expect(CocktailNames.lookupName("金菲士（Gin Fizz）") == "Gin Fizz")
    #expect(CocktailNames.imageSearchTerm("纸飞机（我的配方）") == "Paper Plane")
}

@Test func imageCandidatesRequireSupportedSourcesAndUsableLicenses() throws {
    let candidate = try #require(CocktailPhotoService.decodeCommons(commonsFixture()).first)
    #expect(candidate.credit == "Photo Author" && candidate.license == "CC BY 4.0")
    #expect(candidate.thumbnailURL.host == "thumb.wikimedia.org")
    #expect(try CocktailPhotoService.decodeCommons(commonsFixture(mime: "image/svg+xml")).isEmpty)
    #expect(try CocktailPhotoService.decodeCommons(commonsFixture(license: "https://creativecommons.org/licenses/by-nc/4.0/")).isEmpty)
    #expect(try CocktailPhotoService.decodeCommons(commonsFixture(image: "https://example.com/image.jpg")).isEmpty)
    #expect(try CocktailPhotoService.decodeOpenverse(openverseFixture()).first?.origin == .openverseFlickr)
    #expect(try CocktailPhotoService.decodeOpenverse(openverseFixture(license: "https://creativecommons.org/licenses/by-nd/4.0/")).isEmpty)
    #expect(!CocktailPhotoService.allowedRedirect(from: URL(string: commonsImage)!, to: URL(string: "https://127.0.0.1/image.jpg")!))
    #expect(!CocktailPhotoService.allowedRedirect(from: URL(string: commonsImage)!, to: URL(string: "https://upload.wikimedia.org.evil.test/wikipedia/commons/img.jpg")!))
    #expect(!CocktailPhotoService.isCommonsImage(URL(string: "https://upload.wikimedia.org:8888/wikipedia/commons/img.jpg")!))
}

@Test func commonsFailureStillSearchesOpenverseWithoutSendingPrivateData() async throws {
    let transport = PhotoTransport(openverse: try openverseFixture(), commonsStatus: 503)
    let result = try await CocktailPhotoService(transport: transport).search(name: "纸飞机")
    #expect(result.candidates.count == 1 && result.notices.count == 1)
    let requests = await transport.allRequests()
    #expect(requests.count == 2)
    let request = try #require(requests.last)
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil && request.httpBody == nil)
    let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
    #expect(items.first { $0.name == "q" }?.value == "Paper Plane cocktail")
}

@Test func successfulSearchCachesAndThrottledProviderBacksOff() async throws {
    let transport = PhotoTransport(commons: try commonsFixture(), openverse: try openverseFixture())
    let service = CocktailPhotoService(transport: transport)
    _ = try await service.search(name: "纸飞机")
    _ = try await service.search(name: "Paper Plane")
    #expect(await transport.allRequests().count == 2)
    let throttled = PhotoTransport(commons: try commonsFixture(), openverseStatus: 429)
    let limited = CocktailPhotoService(transport: throttled)
    let first = try await limited.search(name: "Paper Plane")
    #expect(first.candidates.count == 1 && !first.notices.isEmpty)
    _ = try await limited.search(name: "Martini")
    #expect(await throttled.allRequests().filter { $0.url?.host == "api.openverse.org" }.count == 1)
}

@Test func explicitPhotoRefreshBypassesCacheAndKeepsProviderBackoff() async throws {
    let transport = PhotoTransport(commons: try commonsFixture(), openverse: try openverseFixture())
    let service = CocktailPhotoService(transport: transport)
    _ = try await service.search(name: "纸飞机")
    _ = try await service.search(name: "Paper Plane", refresh: true)
    _ = try await service.search(name: "Paper Plane")
    let requests = await transport.allRequests()
    #expect(requests.count == 4)
    #expect(requests.suffix(2).allSatisfy { $0.cachePolicy == .reloadIgnoringLocalCacheData })
    let throttled = PhotoTransport(commons: try commonsFixture(), openverseStatus: 429)
    let limited = CocktailPhotoService(transport: throttled)
    _ = try await limited.search(name: "Paper Plane")
    _ = try await limited.search(name: "Paper Plane", refresh: true)
    #expect(await throttled.allRequests().filter { $0.url?.host == "api.openverse.org" }.count == 1)
    #expect(await throttled.allRequests().filter { $0.url?.host == "commons.wikimedia.org" }.count == 2)
}

@Test func emptyPhotoResultsCanBeRefreshedAndPreviewRetryReloads() async throws {
    let transport = PhotoTransport()
    let service = CocktailPhotoService(transport: transport)
    #expect(try await service.search(name: "纸飞机").candidates.isEmpty)
    _ = try await service.search(name: "纸飞机")
    #expect(await transport.allRequests().count == 2)
    _ = try await service.search(name: "纸飞机", refresh: true)
    #expect(await transport.allRequests().count == 4)
    let candidate = try #require(CocktailPhotoService.decodeCommons(commonsFixture()).first)
    _ = try await service.preview(candidate, refresh: true)
    #expect(await transport.allRequests().last?.cachePolicy == .reloadIgnoringLocalCacheData)
}

@Test @MainActor func missingRecipeAutomaticallySelectsPhotoAndPreservesManualFields() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioFallback-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root)
    let recipe = try store.addCocktail(name: "纸飞机", ingredients: "我的材料 — 45 ml", steps: "我的步骤", notes: "私人备注")
    let transport = PhotoTransport(commons: try commonsFixture(), image: try testPNG())
    let coordinator = CocktailEnrichmentCoordinator(store: store, referenceService: .init(transport: transport), photoService: .init(transport: transport))
    coordinator.startPending()
    try await waitForPhotos(coordinator)
    #expect(coordinator.photoCandidates[recipe.id]?.count == 1)
    #expect(recipe.ingredients == "我的材料 — 45 ml" && recipe.steps == "我的步骤" && recipe.notes == "私人备注" && recipe.name == "纸飞机")
    #expect(FileManager.default.fileExists(atPath: store.cocktailImages.imageURL(for: recipe.id, original: true).path))
    #expect(try store.cocktailPhotoMetadata(for: recipe.id)?.license == "CC BY 4.0")
    #expect(coordinator.errors[recipe.id] == nil)
}

@Test @MainActor func brokenOfficialPhotoFallsBackForCompleteRecipe() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioOfficialFallback-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root)
    let recipe = try store.addCocktail(name: "Martini", ingredients: "金酒 — 50 ml", steps: "搅拌后滤入冷杯。")
    let fixture = try Data(contentsOf: #require(TestResources.url(forResource: "martini-reference", withExtension: "json")))
    let transport = PhotoTransport(commons: try commonsFixture(name: "Martini"), image: try testPNG(), reference: fixture, officialPhotoStatus: 404)
    let coordinator = CocktailEnrichmentCoordinator(store: store, referenceService: .init(transport: transport), photoService: .init(transport: transport))
    coordinator.startPending(); try await waitForPhotos(coordinator)
    #expect(!recipe.ingredients.isEmpty && !recipe.steps.isEmpty)
    #expect(coordinator.photoCandidates[recipe.id]?.count == 1)
    #expect(FileManager.default.fileExists(atPath: store.cocktailImages.imageURL(for: recipe.id, original: true).path))
}

@Test @MainActor func chosenPhotoRechecksSourceAndPersistsLicenseWithLegacyCompatibility() async throws {
    let candidate = try #require(CocktailPhotoService.decodeCommons(commonsFixture()).first)
    let image = try testPNG()
    let transport = PhotoTransport(commons: try commonsFixture(), image: image)
    let (downloaded, metadata) = try await CocktailPhotoService(transport: transport).download(candidate, searchTerm: "Paper Plane")
    #expect(downloaded == image && metadata.credit == "Photo Author" && metadata.license == "CC BY 4.0")
    #expect(metadata.creativeCommonsConfirmed && metadata.usesOriginalPhoto)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioPhotoLicense-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root)
    let recipe = try store.addCocktail(name: "纸飞机", ingredients: "我的材料 — 45 ml", steps: "我的步骤")
    try store.saveCocktailPhoto(id: recipe.id, original: downloaded, sticker: downloaded, thumbnail: downloaded, metadata: metadata)
    let reopened = try CollectionStore(root: root)
    #expect(try reopened.cocktailPhotoMetadata(for: recipe.id) == metadata)
    var legacy = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(metadata)) as? [String: Any])
    legacy["license"] = nil; legacy["licenseURL"] = nil; legacy["searchTerm"] = nil
    let old = try JSONDecoder().decode(CocktailPhotoMetadata.self, from: JSONSerialization.data(withJSONObject: legacy))
    #expect(old.license == nil && old.provider == "Wikimedia Commons")
}

@Test func flickrUsesCurrentSourceLicenseAndRejectsRevokedOrMismatchedSources() async throws {
    let candidate = try #require(CocktailPhotoService.decodeOpenverse(openverseFixture()).first)
    let image = try testPNG()
    let transport = PhotoTransport(image: image, flickr: try flickrFixture())
    let (_, metadata) = try await CocktailPhotoService(transport: transport).download(candidate, searchTerm: "Paper Plane")
    #expect(candidate.license == "CC BY 2.0" && metadata.license == "CC0 1.0")
    #expect(metadata.credit == "Current Author")
    #expect(throws: CocktailPhotoError.sourceChanged) { try CocktailPhotoService.flickrLicense(flickrFixture(license: "https://creativecommons.org/licenses/by-nc-sa/2.0/"), matching: candidate.pageURL) }
    #expect(throws: CocktailPhotoError.sourceChanged) { try CocktailPhotoService.flickrLicense(flickrFixture(photoID: "99"), matching: candidate.pageURL) }
}

@MainActor private func waitForPhotos(_ coordinator: CocktailEnrichmentCoordinator) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(5))
    while coordinator.isWorking, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
    #expect(coordinator.activeIDs.isEmpty)
}

private actor PausedPhotoTransport: AIHTTPTransport {
    var waiting = false
    private var continuation: CheckedContinuation<Void, Never>?
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if request.url?.host == "commons.wikimedia.org" {
            await withCheckedContinuation { continuation in self.continuation = continuation; waiting = true }
            return (try commonsFixture(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        return (Data("{\"results\":[]}".utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
    func release() { continuation?.resume(); continuation = nil }
}

@Test @MainActor func backgroundPhotoSearchDiscardsRenamedDeletedAndUserPhotoResults() async throws {
    for mutation in ["photo", "rename", "delete"] {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioPhotoRace-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try CollectionStore(root: root)
        let recipe = try store.addCocktail(name: "纸飞机", ingredients: "手动材料 — 45 ml", steps: "手动步骤")
        let id = recipe.id
        let delayed = PausedPhotoTransport()
        let coordinator = CocktailEnrichmentCoordinator(store: store, referenceService: .init(transport: PhotoTransport()), photoService: .init(transport: delayed))
        coordinator.startPending()
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !(await delayed.waiting), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
        #expect(await delayed.waiting)
        switch mutation {
        case "photo":
            let image = try testPNG()
            try store.saveCocktailPhoto(id: id, original: image, sticker: image, thumbnail: image, metadata: .init(provider: "自己的照片", usesOriginalPhoto: true))
        case "rename": try store.updateCocktail(recipe, name: "另一款鸡尾酒", ingredients: recipe.ingredients, steps: recipe.steps, glass: "", garnish: "", notes: "", generatedByAI: false)
        default: try store.deleteCocktail(recipe)
        }
        await delayed.release(); try await waitForPhotos(coordinator)
        #expect(coordinator.photoCandidates[id] == nil && coordinator.errors[id] == nil)
        if mutation == "photo" { #expect(try store.cocktailPhotoMetadata(for: id)?.provider == "自己的照片") }
    }
}

private actor PausedPhotoDownloadTransport: AIHTTPTransport {
    let image: Data
    var waiting = false
    var downloads = 0
    private var continuation: CheckedContinuation<Void, Never>?
    init(image: Data) { self.image = image }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url!
        if url.host == "commons.wikimedia.org" {
            if URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.contains(where: { $0.name == "titles" }) == true {
                await withCheckedContinuation { continuation in self.continuation = continuation; waiting = true }
            }
            return (try commonsFixture(), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        if url.host == "upload.wikimedia.org" {
            downloads += 1
            return (image, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        return (Data("{\"results\":[]}".utf8), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
    func release() { continuation?.resume(); continuation = nil }
}

@Test @MainActor func automaticPhotoDownloadDoesNotOverwriteChangesDuringSourceVerification() async throws {
    for mutation in ["photo", "rename", "delete"] {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioAutoPhotoRace-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try CollectionStore(root: root)
        let recipe = try store.addCocktail(name: "纸飞机", ingredients: "手动材料 — 45 ml", steps: "手动步骤")
        let id = recipe.id
        let image = try testPNG()
        let delayed = PausedPhotoDownloadTransport(image: image)
        let coordinator = CocktailEnrichmentCoordinator(store: store, referenceService: .init(transport: PhotoTransport()), photoService: .init(transport: delayed))
        coordinator.startPending()
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !(await delayed.waiting), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
        #expect(await delayed.waiting)
        switch mutation {
        case "photo": try store.saveCocktailPhoto(id: id, original: image, sticker: image, thumbnail: image, metadata: .init(provider: "自己的照片", usesOriginalPhoto: true))
        case "rename": try store.updateCocktail(recipe, name: "另一款配方", ingredients: recipe.ingredients, steps: recipe.steps, glass: "", garnish: "", notes: "", generatedByAI: false)
        default: try store.deleteCocktail(recipe)
        }
        await delayed.release(); try await waitForPhotos(coordinator)
        if mutation == "photo" { #expect(try store.cocktailPhotoMetadata(for: id)?.provider == "自己的照片") }
        else { #expect(!FileManager.default.fileExists(atPath: store.cocktailImages.imageURL(for: id, original: true).path)) }
    }
}

@Test func automaticPhotoAdoptionRejectsChangedDrinkIdentityAtCurrentSource() async throws {
    let candidate = try #require(CocktailPhotoService.decodeCommons(commonsFixture()).first)
    let service = CocktailPhotoService(transport: PhotoTransport(commons: try commonsFixture(name: "Mojito"), image: try testPNG()))
    await #expect(throws: CocktailPhotoError.sourceChanged) {
        _ = try await service.download(candidate, searchTerm: "Paper Plane", matchingName: "Paper Plane")
    }
}

private actor RankedFallbackTransport: AIHTTPTransport {
    let image: Data
    var failedDownloads = 0
    init(image: Data) { self.image = image }
    private func page(_ suffix: String) throws -> [String: Any] {
        let object = try #require(JSONSerialization.jsonObject(with: commonsFixture()) as? [String: Any])
        let query = try #require(object["query"] as? [String: Any])
        let pages = try #require(query["pages"] as? [[String: Any]])
        var page = pages[0]
        page["title"] = "File:Paper_Plane-\(suffix).jpg"
        var info = try #require(page["imageinfo"] as? [[String: Any]])
        info[0]["url"] = "https://upload.wikimedia.org/wikipedia/commons/a/ab/Paper_Plane-\(suffix).jpg"
        info[0]["descriptionurl"] = "https://commons.wikimedia.org/wiki/File:Paper_Plane-\(suffix).jpg"
        page["imageinfo"] = info
        return page
    }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url!
        if url.host == "commons.wikimedia.org" {
            let title = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "titles" })?.value
            let pages = try title.map { [try page($0.contains("-A") ? "A" : "B")] } ?? [page("A"), page("B")]
            let data = try JSONSerialization.data(withJSONObject: ["query": ["pages": pages]])
            return (data, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        if url.host == "upload.wikimedia.org" {
            let status = url.path.contains("-A.jpg") ? 503 : 200
            if status == 503 { failedDownloads += 1 }
            return (image, HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
        return (Data("{\"results\":[]}".utf8), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

@Test @MainActor func automaticPhotoSelectionFallsBackWhenHighestRankedDownloadFails() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("SipfolioRankFallback-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try CollectionStore(root: root)
    let recipe = try store.addCocktail(name: "Paper Plane", ingredients: "手动材料 — 45 ml", steps: "手动步骤")
    let transport = RankedFallbackTransport(image: try testPNG())
    let coordinator = CocktailEnrichmentCoordinator(store: store, referenceService: .init(transport: PhotoTransport()), photoService: .init(transport: transport))
    coordinator.startPending(); try await waitForPhotos(coordinator)
    #expect(await transport.failedDownloads == 1)
    #expect(try store.cocktailPhotoMetadata(for: recipe.id)?.photoURL?.contains("-B.jpg") == true)
    #expect(recipe.ingredients == "手动材料 — 45 ml" && recipe.steps == "手动步骤")
}
