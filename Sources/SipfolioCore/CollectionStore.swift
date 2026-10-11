import Foundation
import SwiftData
import Observation

public struct ImageStore: Sendable {
    public let root: URL
    public init(root: URL) { self.root = root }

    public func directory(for id: UUID) -> URL {
        root.appendingPathComponent(id.uuidString, isDirectory: true)
    }
    public func imageURL(for id: UUID, original: Bool = false) -> URL {
        directory(for: id).appendingPathComponent(original ? "original.png" : "sticker.png")
    }
    public func thumbnailURL(for id: UUID) -> URL {
        directory(for: id).appendingPathComponent("thumbnail.png")
    }

    public func knowledgeURL(for id: UUID) -> URL { directory(for: id).appendingPathComponent("knowledge.json") }
    public func loadKnowledge(for id: UUID) throws -> DrinkKnowledge? {
        let path = knowledgeURL(for: id)
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        return try JSONDecoder().decode(DrinkKnowledge.self, from: Data(contentsOf: path))
    }
    public func saveKnowledge(_ knowledge: DrinkKnowledge, for id: UUID) throws {
        try JSONEncoder().encode(knowledge).write(to: knowledgeURL(for: id), options: .atomic)
    }

    public func save(id: UUID, original: Data, sticker: Data, thumbnail: Data, knowledge: DrinkKnowledge? = nil) throws {
        let directory = directory(for: id)
        // A new UUID directory owns the whole image transaction.
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            try original.write(to: imageURL(for: id, original: true), options: .atomic)
            try sticker.write(to: imageURL(for: id), options: .atomic)
            try thumbnail.write(to: thumbnailURL(for: id), options: .atomic)
            if let knowledge { try saveKnowledge(knowledge, for: id) }
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    public func remove(id: UUID) throws {
        let path = directory(for: id)
        if FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
        }
    }
}

@MainActor @Observable
public final class CollectionStore {
    public let container: ModelContainer
    public let images: ImageStore
    public let cocktailImages: ImageStore
    public let root: URL
    public private(set) var knowledgeRevision = 0
    public private(set) var cocktailImageRevision = 0
    public private(set) var recommendationRevision = 0
    public private(set) var pendingRecommendations: [CocktailRecommendationRequest] = []

    public init(root: URL, inMemory: Bool = false) throws {
        self.root = root
        self.images = ImageStore(root: root.appendingPathComponent("Images", isDirectory: true))
        self.cocktailImages = ImageStore(root: root.appendingPathComponent("CocktailImages", isDirectory: true))
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let schema = Schema([Drink.self, CocktailRecipe.self])
        let configuration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            : ModelConfiguration(schema: schema, url: root.appendingPathComponent("Sipfolio.store"), cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: [configuration])
        container.mainContext.autosaveEnabled = false
        let queueURL = root.appendingPathComponent("recommendations.json")
        if FileManager.default.fileExists(atPath: queueURL.path) {
            pendingRecommendations = try JSONDecoder().decode([CocktailRecommendationRequest].self, from: Data(contentsOf: queueURL))
        }
    }

    public static var defaultRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sipfolio", isDirectory: true)
    }

    @discardableResult
    public func add(name: String, category: String, notes: String, original: Data, sticker: Data, thumbnail: Data, usesOriginalPhoto: Bool, knowledge: DrinkKnowledge? = nil, tasteVariant: String = "", bottleYear: String = "", collectionDate: Date? = nil, includeRecommendedCocktails: Bool = true) throws -> Drink {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw SipfolioError.emptyName }
        let variant = cleanOptional(tasteVariant)
        let year = cleanOptional(bottleYear)
        try validateUniqueWine(cleanName, tasteVariant: variant, bottleYear: year)
        let drink = Drink(name: cleanName, category: CategoryHistory.normalized(category), notes: notes.trimmingCharacters(in: .whitespacesAndNewlines), usesOriginalPhoto: usesOriginalPhoto, tasteVariant: variant, bottleYear: year, collectionDate: collectionDate)
        try images.save(id: drink.id, original: original, sticker: sticker, thumbnail: thumbnail, knowledge: knowledge)
        let context = container.mainContext
        let previousQueue = pendingRecommendations
        context.insert(drink)
        do {
            if includeRecommendedCocktails, let knowledge { _ = try queueRecommendations(knowledge, for: drink) }
            try context.save()
            if knowledge != nil { knowledgeRevision += 1 }
        } catch {
            context.rollback()
            try? saveRecommendationQueue(previousQueue)
            try? images.remove(id: drink.id)
            throw error
        }
        return drink
    }

    public func update(_ drink: Drink, name: String, category: String, notes: String, tasteVariant: String? = nil, bottleYear: String? = nil, collectionDate: Date? = nil) throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw SipfolioError.emptyName }
        let variant = tasteVariant.map(cleanOptional) ?? drink.tasteVariant
        let year = bottleYear.map(cleanOptional) ?? drink.bottleYear
        try validateUniqueWine(cleanName, tasteVariant: variant, bottleYear: year, excluding: drink.id)
        drink.name = cleanName
        drink.category = CategoryHistory.normalized(category)
        drink.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        drink.tasteVariant = variant
        drink.bottleYear = year
        if let collectionDate { drink.collectionDateOverride = collectionDate }
        do { try container.mainContext.save() }
        catch { container.mainContext.rollback(); throw error }
    }

    public func applyKnowledge(_ knowledge: DrinkKnowledge, to drink: Drink) throws {
        let name = knowledge.name ?? drink.name
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw SipfolioError.emptyName }
        try validateUniqueWine(name.trimmingCharacters(in: .whitespacesAndNewlines), tasteVariant: drink.tasteVariant, bottleYear: drink.bottleYear, excluding: drink.id)
        let url = images.knowledgeURL(for: drink.id)
        let previous = FileManager.default.fileExists(atPath: url.path) ? try Data(contentsOf: url) : nil
        let previousQueue = pendingRecommendations
        try images.saveKnowledge(knowledge, for: drink.id)
        do {
            drink.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            drink.category = CategoryHistory.normalized(knowledge.category ?? drink.category)
            _ = try queueRecommendations(knowledge, for: drink)
            try container.mainContext.save()
            knowledgeRevision += 1
        }
        catch {
            container.mainContext.rollback()
            try? saveRecommendationQueue(previousQueue)
            if let previous { try? previous.write(to: url, options: .atomic) }
            else { try? FileManager.default.removeItem(at: url) }
            throw error
        }
    }

    @discardableResult
    public func delete(_ drink: Drink) throws -> String? {
        let id = drink.id
        container.mainContext.delete(drink)
        do { try container.mainContext.save() }
        catch { container.mainContext.rollback(); throw error }
        // Commit the record deletion before removing its images. A save failure must not lose photos.
        do { try images.remove(id: id); return nil }
        catch { return "收藏记录已删除，但图片文件未能清理：\(error.localizedDescription)" }
    }

    public func allDrinks() throws -> [Drink] {
        try container.mainContext.fetch(FetchDescriptor<Drink>(sortBy: [SortDescriptor(\Drink.createdAt, order: .reverse)]))
    }

    public func allCocktails() throws -> [CocktailRecipe] {
        try container.mainContext.fetch(FetchDescriptor<CocktailRecipe>(sortBy: [SortDescriptor(\CocktailRecipe.createdAt, order: .reverse)]))
    }

    @discardableResult
    public func collectRecommendations(_ knowledge: DrinkKnowledge, for drink: Drink) throws -> [CocktailRecommendationRequest] {
        try queueRecommendations(knowledge, for: drink)
    }

    private func queueRecommendations(_ knowledge: DrinkKnowledge, for drink: Drink) throws -> [CocktailRecommendationRequest] {
        var queue = pendingRecommendations
        let source = CocktailBottleSource(id: drink.id, name: [drink.name, drink.variantDescription].filter { !$0.isEmpty }.joined(separator: " · "))
        var result: [CocktailRecommendationRequest] = []
        for value in knowledge.cocktails {
            let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let key = CocktailNames.key(name)
            if let index = queue.firstIndex(where: { $0.id == key }) {
                if !queue[index].sources.contains(where: { $0.id == source.id }) { queue[index].sources.append(source) }
            } else { queue.append(CocktailRecommendationRequest(name: name, sources: [source])) }
            if !result.contains(where: { $0.id == key }), let request = queue.first(where: { $0.id == key }) { result.append(request) }
        }
        try saveRecommendationQueue(queue)
        return result
    }

    private func saveRecommendationQueue(_ queue: [CocktailRecommendationRequest]) throws {
        try JSONEncoder().encode(queue).write(to: root.appendingPathComponent("recommendations.json"), options: .atomic)
        pendingRecommendations = queue
        recommendationRevision += 1
    }

    public func finishRecommendation(_ key: String) throws {
        try saveRecommendationQueue(pendingRecommendations.filter { $0.id != key })
    }

    /// The recommendation is admitted only after its complete, measured recipe is available.
    @discardableResult
    public func admitRecommendation(_ key: String, reference: CocktailReference?) throws -> CocktailRecipe? {
        guard let request = pendingRecommendations.first(where: { $0.id == key }) else { return nil }
        let existing = try allCocktails().first { CocktailNames.key($0.name) == key && CocktailAdmission.accepts(ingredients: $0.ingredients, steps: $0.steps) }
        let recipe: CocktailRecipe
        if let existing { recipe = existing }
        else {
            guard let reference, CocktailNames.key(reference.suggestion.name) == key, CocktailAdmission.accepts(reference.suggestion) else { return nil }
            var legacy: ArchivedCocktailRecipe?
            if let id = request.legacyRecipeID {
                let archive = try JSONDecoder().decode([ArchivedCocktailRecipe].self, from: Data(contentsOf: root.appendingPathComponent("incomplete-recipes-archive.json")))
                legacy = archive.first { $0.id == id }
            }
            recipe = CocktailRecipe(id: legacy?.id ?? UUID(), name: request.name,
                                    ingredients: legacy?.ingredients.isEmpty == false ? legacy!.ingredients : reference.suggestion.ingredientsText,
                                    steps: legacy?.steps.isEmpty == false ? legacy!.steps : reference.suggestion.stepsText,
                                    glass: legacy?.glass.isEmpty == false ? legacy!.glass : reference.suggestion.glass,
                                    garnish: legacy?.garnish.isEmpty == false ? legacy!.garnish : reference.suggestion.garnish,
                                    notes: legacy?.notes ?? "", createdAt: legacy?.createdAt ?? .now, generatedByAI: legacy?.generatedByAI ?? false)
            guard CocktailAdmission.accepts(ingredients: recipe.ingredients, steps: recipe.steps) else { return nil }
            recipe.referenceURL = reference.pageURL.absoluteString
            recipe.referenceProvider = "TheCocktailDB"
            container.mainContext.insert(recipe)
        }
        var sources = recipe.linkedSources
        for source in request.sources where !sources.contains(where: { $0.id == source.id }) { sources.append(source) }
        recipe.sourcesJSON = String(data: try JSONEncoder().encode(sources), encoding: .utf8)
        do { try container.mainContext.save() }
        catch { container.mainContext.rollback(); throw error }
        if let id = request.legacyRecipeID { try markArchivedRecipeResolved(id) }
        try finishRecommendation(key)
        return recipe
    }

    /// Preserve legacy data and photos locally before taking unusable entries out of the collection.
    public func archiveIncompleteCocktails() throws {
        let incomplete = try allCocktails().filter { !CocktailAdmission.accepts(ingredients: $0.ingredients, steps: $0.steps) }
        guard !incomplete.isEmpty else { return }
        let archiveURL = root.appendingPathComponent("incomplete-recipes-archive.json")
        var archive = FileManager.default.fileExists(atPath: archiveURL.path)
            ? try JSONDecoder().decode([ArchivedCocktailRecipe].self, from: Data(contentsOf: archiveURL)) : []
        for recipe in incomplete where !archive.contains(where: { $0.id == recipe.id }) { archive.append(ArchivedCocktailRecipe(recipe)) }
        try JSONEncoder().encode(archive).write(to: archiveURL, options: .atomic)
        var queue = pendingRecommendations
        for recipe in incomplete where !recipe.linkedSources.isEmpty && (recipe.ingredients.isEmpty || CocktailAdmission.accepts(ingredients: recipe.ingredients, steps: "制作步骤")) {
            let key = CocktailNames.key(recipe.name)
            if let index = queue.firstIndex(where: { $0.id == key }) {
                for source in recipe.linkedSources where !queue[index].sources.contains(where: { $0.id == source.id }) { queue[index].sources.append(source) }
                if queue[index].legacyRecipeID == nil { queue[index].legacyRecipeID = recipe.id }
            } else {
                var request = CocktailRecommendationRequest(name: recipe.name, sources: recipe.linkedSources)
                request.legacyRecipeID = recipe.id
                queue.append(request)
            }
        }
        try saveRecommendationQueue(queue)
        for recipe in incomplete { container.mainContext.delete(recipe) }
        do { try container.mainContext.save() }
        catch { container.mainContext.rollback(); throw error }
        // Their media directories stay with the recovery archive; no user photo is destroyed.
    }

    /// A source quantity that cannot become a ratio does not make an otherwise usable recipe invalid.
    public func restoreUsableArchivedCocktails() throws {
        let archiveURL = root.appendingPathComponent("incomplete-recipes-archive.json")
        guard FileManager.default.fileExists(atPath: archiveURL.path) else { return }
        var archive = try JSONDecoder().decode([ArchivedCocktailRecipe].self, from: Data(contentsOf: archiveURL))
        var existing = try allCocktails()
        var changed = false, archiveChanged = false
        for index in archive.indices {
            let value = archive[index]
            guard value.restoredAt == nil, CocktailAdmission.accepts(ingredients: value.ingredients, steps: value.steps) else { continue }
            archive[index].restoredAt = .now; archiveChanged = true
            guard !existing.contains(where: { $0.id == value.id }) else { continue }
            if let saved = existing.first(where: { CocktailNames.key($0.name) == CocktailNames.key(value.name) }) {
                var sources = saved.linkedSources
                for source in value.sources where !sources.contains(where: { $0.id == source.id }) { sources.append(source) }
                if sources != saved.linkedSources {
                    saved.sourcesJSON = String(data: try JSONEncoder().encode(sources), encoding: .utf8)
                    changed = true
                }
                continue
            }
            let recipe = CocktailRecipe(id: value.id, name: value.name, ingredients: value.ingredients, steps: value.steps,
                                        glass: value.glass, garnish: value.garnish, notes: value.notes, createdAt: value.createdAt,
                                        generatedByAI: value.generatedByAI)
            recipe.sourcesJSON = String(data: try JSONEncoder().encode(value.sources), encoding: .utf8)
            recipe.referenceURL = value.referenceURL; recipe.referenceProvider = value.referenceProvider
            container.mainContext.insert(recipe); existing.append(recipe); changed = true
        }
        if changed {
            do { try container.mainContext.save() }
            catch { container.mainContext.rollback(); throw error }
        }
        if archiveChanged { try JSONEncoder().encode(archive).write(to: archiveURL, options: .atomic) }
    }

    private func markArchivedRecipeResolved(_ id: UUID) throws {
        let url = root.appendingPathComponent("incomplete-recipes-archive.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        var archive = try JSONDecoder().decode([ArchivedCocktailRecipe].self, from: Data(contentsOf: url))
        guard let index = archive.firstIndex(where: { $0.id == id && $0.restoredAt == nil }) else { return }
        archive[index].restoredAt = .now
        try JSONEncoder().encode(archive).write(to: url, options: .atomic)
    }

    public func applyReference(_ reference: CocktailReference, to recipeID: UUID) throws {
        guard let recipe = try allCocktails().first(where: { $0.id == recipeID }) else { return }
        guard CocktailNames.key(recipe.name) == CocktailNames.key(reference.suggestion.name) else { return }
        // Enrichment only fills blanks, preserving the user's own recipe and edits.
        if recipe.ingredients.isEmpty { recipe.ingredients = reference.suggestion.ingredientsText }
        if recipe.steps.isEmpty { recipe.steps = reference.suggestion.stepsText }
        if recipe.glass.isEmpty { recipe.glass = reference.suggestion.glass }
        if recipe.garnish.isEmpty { recipe.garnish = reference.suggestion.garnish }
        recipe.referenceURL = reference.pageURL.absoluteString
        recipe.referenceProvider = "TheCocktailDB"
        do { try container.mainContext.save() }
        catch { container.mainContext.rollback(); throw error }
    }

    public func saveCocktailPhoto(id: UUID, original: Data, sticker: Data, thumbnail: Data, metadata: CocktailPhotoMetadata) throws {
        guard try allCocktails().contains(where: { $0.id == id }) else { return }
        let directory = cocktailImages.directory(for: id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Install complete media as a directory swap so a failed replacement keeps the prior photo.
        let staging = cocktailImages.root.appendingPathComponent("stage-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        try original.write(to: staging.appendingPathComponent("original.png"), options: .atomic)
        try sticker.write(to: staging.appendingPathComponent("sticker.png"), options: .atomic)
        try thumbnail.write(to: staging.appendingPathComponent("thumbnail.png"), options: .atomic)
        try JSONEncoder().encode(metadata).write(to: staging.appendingPathComponent("photo.json"), options: .atomic)
        let backup = cocktailImages.root.appendingPathComponent("backup-\(UUID())", isDirectory: true)
        try FileManager.default.moveItem(at: directory, to: backup)
        do { try FileManager.default.moveItem(at: staging, to: directory) }
        catch { try? FileManager.default.moveItem(at: backup, to: directory); throw error }
        try? FileManager.default.removeItem(at: backup)
        cocktailImageRevision += 1
    }

    public func cocktailPhotoMetadata(for id: UUID) throws -> CocktailPhotoMetadata? {
        let url = cocktailImages.directory(for: id).appendingPathComponent("photo.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(CocktailPhotoMetadata.self, from: Data(contentsOf: url))
    }

    @discardableResult
    public func addCocktail(name: String, ingredients: String, steps: String, glass: String = "", garnish: String = "", notes: String = "", sourceDrinkID: UUID? = nil, sourceDrinkName: String? = nil, generatedByAI: Bool = false) throws -> CocktailRecipe {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw CocktailError.emptyName }
        guard CocktailAdmission.accepts(ingredients: ingredients, steps: steps) else { throw CocktailError.incompleteRecipe }
        let recipe = CocktailRecipe(name: cleanName, ingredients: ingredients.trimmingCharacters(in: .whitespacesAndNewlines), steps: steps.trimmingCharacters(in: .whitespacesAndNewlines), glass: glass.trimmingCharacters(in: .whitespacesAndNewlines), garnish: garnish.trimmingCharacters(in: .whitespacesAndNewlines), notes: notes.trimmingCharacters(in: .whitespacesAndNewlines), sourceDrinkID: sourceDrinkID, sourceDrinkName: cleanOptional(sourceDrinkName ?? ""), generatedByAI: generatedByAI)
        container.mainContext.insert(recipe)
        do { try container.mainContext.save() }
        catch { container.mainContext.rollback(); throw error }
        return recipe
    }

    public func updateCocktail(_ recipe: CocktailRecipe, name: String, ingredients: String, steps: String, glass: String, garnish: String, notes: String, generatedByAI: Bool) throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw CocktailError.emptyName }
        guard CocktailAdmission.accepts(ingredients: ingredients, steps: steps) else { throw CocktailError.incompleteRecipe }
        recipe.name = cleanName
        recipe.ingredients = ingredients.trimmingCharacters(in: .whitespacesAndNewlines)
        recipe.steps = steps.trimmingCharacters(in: .whitespacesAndNewlines)
        recipe.glass = glass.trimmingCharacters(in: .whitespacesAndNewlines)
        recipe.garnish = garnish.trimmingCharacters(in: .whitespacesAndNewlines)
        recipe.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        recipe.generatedByAI = generatedByAI
        do { try container.mainContext.save() }
        catch { container.mainContext.rollback(); throw error }
    }

    public func deleteCocktail(_ recipe: CocktailRecipe) throws {
        let id = recipe.id
        try markArchivedRecipeResolved(id)
        container.mainContext.delete(recipe)
        do { try container.mainContext.save() }
        catch { container.mainContext.rollback(); throw error }
        try? cocktailImages.remove(id: id)
    }

    private func cleanOptional(_ text: String) -> String? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    private func validateUniqueWine(_ name: String, tasteVariant: String?, bottleYear: String?, excluding id: UUID? = nil) throws {
        func matches(_ lhs: String?, _ rhs: String?) -> Bool {
            (lhs ?? "").compare(rhs ?? "", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        if try allDrinks().contains(where: {
            $0.id != id && matches($0.name, name) && matches($0.tasteVariant, tasteVariant) && matches($0.bottleYear, bottleYear)
        }) { throw SipfolioError.duplicateName }
    }
}
