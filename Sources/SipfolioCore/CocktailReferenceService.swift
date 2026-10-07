import Foundation
import Observation

public struct CocktailReference: Sendable {
    public let suggestion: CocktailSuggestion
    public let pageURL: URL
    public let photoURL: URL?
    public let photoSourceURL: URL?
    public let photoCredit: String
    public let creativeCommonsConfirmed: Bool
}

public struct CocktailPhotoMetadata: Codable, Sendable, Equatable {
    public let provider: String
    public let pageURL: String?
    public let photoURL: String?
    public let photoSourceURL: String?
    public let credit: String
    public let creativeCommonsConfirmed: Bool
    public let usesOriginalPhoto: Bool
    public let savedAt: Date
    public init(provider: String, pageURL: String? = nil, photoURL: String? = nil, photoSourceURL: String? = nil, credit: String = "", creativeCommonsConfirmed: Bool = false, usesOriginalPhoto: Bool = false, savedAt: Date = .now) {
        self.provider = provider; self.pageURL = pageURL; self.photoURL = photoURL; self.photoSourceURL = photoSourceURL
        self.credit = credit; self.creativeCommonsConfirmed = creativeCommonsConfirmed; self.usesOriginalPhoto = usesOriginalPhoto; self.savedAt = savedAt
    }
}

public enum CocktailReferenceError: LocalizedError, Equatable {
    case notFound, invalidResponse, invalidImageURL, http(Int)
    public var errorDescription: String? {
        switch self {
        case .notFound: "没有找到名称匹配的公开配方，可修改名称后重试，或手动补充。"
        case .invalidResponse: "公开配方数据暂时无法读取，请稍后重试。"
        case .invalidImageURL: "成品图地址不可用，可以导入自己的照片。"
        case .http: "联网获取配方或成品图失败，请稍后重试。"
        }
    }
}

public actor CocktailReferenceService {
    private let transport: any AIHTTPTransport
    public init(transport: any AIHTTPTransport = AIURLSessionTransport()) { self.transport = transport }

    public func lookup(name: String) async throws -> CocktailReference {
        var components = URLComponents(string: "https://www.thecocktaildb.com/api/json/v1/1/search.php")!
        components.queryItems = [URLQueryItem(name: "s", value: CocktailNames.lookupName(name))]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 25
        let (data, response) = try await transport.data(for: request)
        try Task.checkCancellation()
        guard (200..<300).contains(response.statusCode) else { throw CocktailReferenceError.http(response.statusCode) }
        return try Self.decode(data, matching: name)
    }

    public func downloadPhoto(_ url: URL) async throws -> Data {
        guard url.scheme == "https", ["www.thecocktaildb.com", "thecocktaildb.com"].contains(url.host), url.path.hasPrefix("/images/media/drink/") else { throw CocktailReferenceError.invalidImageURL }
        var request = URLRequest(url: url); request.timeoutInterval = 25
        let (data, response) = try await transport.data(for: request)
        try Task.checkCancellation()
        guard (200..<300).contains(response.statusCode) else { throw CocktailReferenceError.http(response.statusCode) }
        guard data.count <= 15 * 1024 * 1024, response.url?.scheme == "https", ["www.thecocktaildb.com", "thecocktaildb.com"].contains(response.url?.host) else { throw CocktailReferenceError.invalidImageURL }
        return data
    }

    public static func decode(_ data: Data, matching name: String) throws -> CocktailReference {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw CocktailReferenceError.invalidResponse }
        guard let drinks = object["drinks"] as? [[String: Any]] else { throw CocktailReferenceError.notFound }
        let expected = CocktailNames.key(name)
        guard let drink = drinks.first(where: { CocktailNames.key($0["strDrink"] as? String ?? "") == expected }) else { throw CocktailReferenceError.notFound }
        func value(_ key: String) -> String { String((drink[key] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(2000)) }
        guard let id = Int(value("idDrink")), !value("strDrink").isEmpty else { throw CocktailReferenceError.invalidResponse }
        let translations = ["Gin": "金酒", "Tonic water": "汤力水", "Lime": "青柠", "Lemon": "柠檬", "Vodka": "伏特加", "Light rum": "淡朗姆酒", "Dark rum": "深色朗姆酒", "Sugar": "糖", "Sugar syrup": "糖浆", "Ice": "冰块", "Mint": "薄荷", "Tequila": "龙舌兰酒", "Triple sec": "橙味利口酒", "Dry Vermouth": "干味美思", "Sweet Vermouth": "甜味美思"]
        var ingredients: [CocktailSuggestion.Ingredient] = []
        for index in 1...15 {
            let ingredient = value("strIngredient\(index)")
            guard !ingredient.isEmpty else { continue }
            let measure = value("strMeasure\(index)")
            ingredients.append(.init(name: translations[ingredient] ?? ingredient, amount: measure.isEmpty ? "来源未注明用量" : measure))
        }
        let chinese = value("strInstructionsZH-HANS")
        let instructions = chinese.isEmpty ? value("strInstructions") : chinese
        let glasses = ["Highball glass": "高球杯", "Cocktail glass": "鸡尾酒杯", "Old-fashioned glass": "古典杯", "Collins glass": "柯林杯", "Martini Glass": "马提尼杯"]
        let suggestion = CocktailSuggestion(name: value("strDrink"), ingredients: ingredients, steps: instructions.isEmpty ? [] : [instructions], glass: glasses[value("strGlass")] ?? value("strGlass"), garnish: "", notes: "")
        let confirmed = value("strCreativeCommonsConfirmed").lowercased() == "yes"
        // CC confirmation describes licensing metadata, not whether an API photograph exists.
        // Official API artwork is used intact with attribution for this local development app.
        let photo = URL(string: value("strDrinkThumb"))
        let validPhoto = photo.flatMap { url -> URL? in
            guard url.scheme == "https", ["www.thecocktaildb.com", "thecocktaildb.com"].contains(url.host), url.path.hasPrefix("/images/media/drink/") else { return nil }
            return url
        }
        let source = URL(string: value("strImageSource")).flatMap { ["https", "http"].contains($0.scheme ?? "") ? $0 : nil }
        return CocktailReference(suggestion: suggestion, pageURL: URL(string: "https://www.thecocktaildb.com/drink/\(id)")!, photoURL: validPhoto, photoSourceURL: source, photoCredit: value("strImageAttribution"), creativeCommonsConfirmed: confirmed)
    }
}

@MainActor @Observable
public final class CocktailEnrichmentCoordinator {
    public private(set) var activeIDs: Set<UUID> = []
    public private(set) var errors: [UUID: String] = [:]
    private let store: CollectionStore
    private let referenceService: CocktailReferenceService
    private let imageService = BottleCutoutService()
    private var pending: [UUID] = []
    private var worker: Task<Void, Never>?

    public init(store: CollectionStore, referenceService: CocktailReferenceService = CocktailReferenceService()) {
        self.store = store; self.referenceService = referenceService
    }

    public func startPending() {
        guard let recipes = try? store.allCocktails() else { return }
        for recipe in recipes where errors[recipe.id] == nil {
            let missingPhoto = !FileManager.default.fileExists(atPath: store.cocktailImages.imageURL(for: recipe.id, original: true).path)
            if missingPhoto || recipe.ingredients.isEmpty || recipe.steps.isEmpty { enqueue(recipe.id) }
        }
        startWorker()
    }

    public func retry(_ id: UUID) { errors[id] = nil; enqueue(id); startWorker() }
    private func enqueue(_ id: UUID) {
        guard !activeIDs.contains(id), !pending.contains(id) else { return }
        pending.append(id); activeIDs.insert(id)
    }
    private func startWorker() {
        guard worker == nil, !pending.isEmpty else { return }
        worker = Task { @MainActor in
            while !pending.isEmpty, !Task.isCancelled {
                let id = pending.removeFirst()
                await enrich(id)
                activeIDs.remove(id)
            }
            worker = nil
        }
    }
    private func enrich(_ id: UUID) async {
        guard let recipe = try? store.allCocktails().first(where: { $0.id == id }) else { return }
        let name = recipe.name
        do {
            let reference = try await referenceService.lookup(name: name)
            guard let current = try store.allCocktails().first(where: { $0.id == id }), CocktailNames.key(current.name) == CocktailNames.key(name) else { return }
            try store.applyReference(reference, to: id)
            // A user-selected photograph must survive reference refreshes.
            if FileManager.default.fileExists(atPath: store.cocktailImages.imageURL(for: id, original: true).path) { return }
            guard let photoURL = reference.photoURL else {
                errors[id] = "已找到配方，但接口未提供可用的成品图；可以导入自己的照片。"
                return
            }
            let downloaded = try await referenceService.downloadPhoto(photoURL)
            let original = try await imageService.normalizedPNG(from: downloaded, maxPixelSize: 1600)
            let thumbnail = try await imageService.normalizedPNG(from: original, maxPixelSize: 420)
            guard let latest = try store.allCocktails().first(where: { $0.id == id }), CocktailNames.key(latest.name) == CocktailNames.key(name),
                  !FileManager.default.fileExists(atPath: store.cocktailImages.imageURL(for: id, original: true).path) else { return }
            let metadata = CocktailPhotoMetadata(provider: "TheCocktailDB", pageURL: reference.pageURL.absoluteString, photoURL: photoURL.absoluteString, photoSourceURL: reference.photoSourceURL?.absoluteString, credit: reference.photoCredit, creativeCommonsConfirmed: reference.creativeCommonsConfirmed, usesOriginalPhoto: true)
            try store.saveCocktailPhoto(id: id, original: original, sticker: original, thumbnail: thumbnail, metadata: metadata)
        } catch { if !Task.isCancelled { errors[id] = error.localizedDescription } }
    }
}
