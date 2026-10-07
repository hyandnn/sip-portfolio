import Foundation
import SwiftData

@Model
public final class CocktailRecipe {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var ingredients: String
    public var steps: String
    public var glass: String
    public var garnish: String
    public var notes: String
    public var createdAt: Date
    public var sourceDrinkID: UUID?
    public var sourceDrinkName: String?
    public var generatedByAI: Bool
    public var sourcesJSON: String? = nil
    public var referenceURL: String? = nil
    public var referenceProvider: String? = nil

    public init(id: UUID = UUID(), name: String, ingredients: String = "", steps: String = "", glass: String = "", garnish: String = "", notes: String = "", createdAt: Date = .now, sourceDrinkID: UUID? = nil, sourceDrinkName: String? = nil, generatedByAI: Bool = false) {
        self.id = id; self.name = name; self.ingredients = ingredients; self.steps = steps
        self.glass = glass; self.garnish = garnish; self.notes = notes; self.createdAt = createdAt
        self.sourceDrinkID = sourceDrinkID; self.sourceDrinkName = sourceDrinkName; self.generatedByAI = generatedByAI
    }

    public var linkedSources: [CocktailBottleSource] {
        if let json = sourcesJSON, let data = json.data(using: .utf8), let sources = try? JSONDecoder().decode([CocktailBottleSource].self, from: data) { return sources }
        if let sourceDrinkID, let sourceDrinkName { return [CocktailBottleSource(id: sourceDrinkID, name: sourceDrinkName)] }
        return []
    }

    public var sourceDescription: String { linkedSources.map(\.name).joined(separator: "、") }
}

public struct CocktailBottleSource: Codable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public init(id: UUID, name: String) { self.id = id; self.name = name }
}

public enum CocktailNames {
    public static func lookupName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.components(separatedBy: CharacterSet(charactersIn: "(（")).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed
        let key = base.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let aliases: [(String, [String])] = [
            ("Gin and Tonic", ["gin & tonic", "gin and tonic", "金汤力", "金汤尼", "金酒汤力"]),
            ("Martini", ["martini", "马天尼", "马提尼"]),
            ("Negroni", ["negroni", "尼格罗尼", "内格罗尼"]),
            ("Margarita", ["margarita", "玛格丽特"]),
            ("Mojito", ["mojito", "莫吉托"]),
            ("Daiquiri", ["daiquiri", "戴基里", "代基里"]),
            ("Old Fashioned", ["old fashioned", "古典鸡尾酒"]),
            ("Whiskey Sour", ["whiskey sour", "whisky sour", "威士忌酸"]),
            ("Manhattan", ["manhattan", "曼哈顿"]),
            ("Bloody Mary", ["bloody mary", "血腥玛丽"]),
            ("Cosmopolitan", ["cosmopolitan", "大都会"]),
            ("Pina Colada", ["pina colada", "椰林飘香"]),
            ("Aperol Spritz", ["aperol spritz", "阿佩罗"])
        ]
        for (canonical, aliases) in aliases where aliases.contains(where: { key == $0 }) { return canonical }
        return base
    }

    public static func key(_ name: String) -> String {
        lookupName(name).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    }
}

public struct CocktailSuggestion: Codable, Sendable, Equatable {
    public struct Ingredient: Codable, Sendable, Equatable {
        public let name: String
        public let amount: String
        public init(name: String, amount: String) { self.name = name; self.amount = amount }
    }
    public var name: String
    public var ingredients: [Ingredient]
    public var steps: [String]
    public var glass: String
    public var garnish: String
    public var notes: String

    public var ingredientsText: String {
        ingredients.map { "\($0.name) — \($0.amount)" }.joined(separator: "\n")
    }
    public var stepsText: String {
        steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
    }
}

public enum CocktailError: LocalizedError {
    case emptyName
    public var errorDescription: String? { "请填写鸡尾酒名称。" }
}

public enum CategoryHistory {
    /// Only categories the user has actually saved, ordered by recent use.
    public static func suggestions(from categories: [String], matching query: String = "") -> [String] {
        var seen = Set<String>()
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return categories.compactMap { value in
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = clean.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard !clean.isEmpty, seen.insert(key).inserted,
                  query.isEmpty || clean.localizedStandardContains(query) else { return nil }
            return clean
        }
    }

    public static func normalized(_ value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "未分类" : clean
    }
}
