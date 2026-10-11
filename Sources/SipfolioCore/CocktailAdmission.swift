import Foundation

public enum CocktailAdmission {
    /// Keep usable recipes even when source quantities cannot be converted to a ratio.
    public static func accepts(ingredients: String, steps: String) -> Bool {
        let lines = ingredients.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return !lines.isEmpty && hasInstructions(steps) && lines.allSatisfy(hasIngredientName)
    }

    public static func accepts(_ suggestion: CocktailSuggestion) -> Bool {
        !suggestion.ingredients.isEmpty && suggestion.ingredients.allSatisfy {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } && suggestion.steps.contains(where: hasInstructions)
    }

    private static func hasInstructions(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !["待补充", "待补配方", "暂无步骤", "暂无配方", "来源未提供步骤", "tbd", "todo"].contains(trimmed) else { return false }
        return trimmed.unicodeScalars.contains { CharacterSet.letters.contains($0) }
    }

    private static func hasIngredientName(_ line: String) -> Bool {
        let prefix: String
        if line.contains("—") { prefix = line.components(separatedBy: "—").first ?? "" }
        else if let number = line.firstIndex(where: { $0.isNumber }) { prefix = String(line[..<number]) }
        else { prefix = line }
        return prefix.unicodeScalars.contains { CharacterSet.letters.contains($0) }
    }
}

public enum CocktailCollectionBook: String, CaseIterable, Sendable {
    case photos = "杯中画"
    case text = "调酒笺"
    public func includes(hasPhoto: Bool) -> Bool { self == .photos ? hasPhoto : !hasPhoto }
}

public struct CocktailRecommendationRequest: Codable, Sendable, Equatable, Identifiable {
    public var name: String
    public var sources: [CocktailBottleSource]
    public var legacyRecipeID: UUID? = nil
    public var id: String { CocktailNames.key(name) }
    public init(name: String, sources: [CocktailBottleSource]) { self.name = name; self.sources = sources }
}

/// Recovery copies of legacy incomplete records, outside the usable recipe collection.
struct ArchivedCocktailRecipe: Codable {
    var restoredAt: Date? = nil
    let id: UUID
    let name: String
    let ingredients: String
    let steps: String
    let glass: String
    let garnish: String
    let notes: String
    let createdAt: Date
    let sources: [CocktailBottleSource]
    let generatedByAI: Bool
    let referenceURL: String?
    let referenceProvider: String?
    init(_ recipe: CocktailRecipe) {
        id = recipe.id; name = recipe.name; ingredients = recipe.ingredients; steps = recipe.steps
        glass = recipe.glass; garnish = recipe.garnish; notes = recipe.notes; createdAt = recipe.createdAt
        sources = recipe.linkedSources; generatedByAI = recipe.generatedByAI
        referenceURL = recipe.referenceURL; referenceProvider = recipe.referenceProvider
    }
}
