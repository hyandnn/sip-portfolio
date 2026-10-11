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
    private static let aliases: [(String, [String])] = [
        ("Highball", ["highball", "高球", "海波", "海波酒"]),
        ("Gin and Tonic", ["gin & tonic", "gin and tonic", "gin tonic", "g&t", "金汤力", "金汤尼", "金酒汤力"]),
        ("Martini", ["martini", "马天尼", "马提尼"]),
        ("Negroni", ["negroni", "尼格罗尼", "内格罗尼"]),
        ("Margarita", ["margarita", "玛格丽特"]),
        ("Mojito", ["mojito", "莫吉托"]),
        ("Daiquiri", ["daiquiri", "戴基里", "代基里"]),
        ("Old Fashioned", ["old fashioned", "古典鸡尾酒", "古典"]),
        ("Whiskey Sour", ["whiskey sour", "whisky sour", "威士忌酸"]),
        ("Manhattan", ["manhattan", "曼哈顿"]),
        ("Bloody Mary", ["bloody mary", "血腥玛丽"]),
        ("Cosmopolitan", ["cosmopolitan", "大都会"]),
        ("Pina Colada", ["pina colada", "椰林飘香"]),
        ("Aperol Spritz", ["aperol spritz", "阿佩罗", "阿佩罗气泡酒"]),
        ("French 75", ["french 75", "法式75", "法式七五", "法国75"]),
        ("Gin Fizz", ["gin fizz", "金菲士", "金费士", "金酒菲士"]),
        ("Ramos Gin Fizz", ["ramos gin fizz", "拉莫斯金菲士"]),
        ("Tom Collins", ["tom collins", "汤姆柯林斯", "汤姆科林斯"]),
        ("Singapore Sling", ["singapore sling", "新加坡司令"]),
        ("Espresso Martini", ["espresso martini", "浓缩咖啡马天尼", "浓缩咖啡马提尼"]),
        ("Dry Martini", ["dry martini", "干马天尼", "干马提尼"]),
        ("Dirty Martini", ["dirty martini", "脏马天尼", "脏马提尼"]),
        ("Moscow Mule", ["moscow mule", "莫斯科骡子", "莫斯科之骡"]),
        ("Dark 'n' Stormy", ["dark n stormy", "dark and stormy", "黑暗风暴"]),
        ("Mai Tai", ["mai tai", "迈泰"]),
        ("Paloma", ["paloma", "帕洛玛"]),
        ("Boulevardier", ["boulevardier", "林荫大道", "大道"]),
        ("Sidecar", ["sidecar", "边车"]),
        ("White Lady", ["white lady", "白色佳人", "白色女士"]),
        ("White Russian", ["white russian", "白俄罗斯"]),
        ("Black Russian", ["black russian", "黑俄罗斯"]),
        ("Cuba Libre", ["cuba libre", "自由古巴"]),
        ("Caipirinha", ["caipirinha", "凯匹林纳", "卡皮里尼亚"]),
        ("Aviation", ["aviation", "航空"]),
        ("Last Word", ["last word", "最后的话", "最后一句"]),
        ("Paper Plane", ["paper plane", "纸飞机"]),
        ("Penicillin", ["penicillin", "盘尼西林", "青霉素"]),
        ("Bee's Knees", ["bees knees", "蜂膝", "蜜蜂之膝"]),
        ("Clover Club", ["clover club", "三叶草俱乐部"]),
        ("Bramble", ["bramble", "荆棘"]),
        ("Negroni Sbagliato", ["negroni sbagliato", "错误的尼格罗尼", "错误的内格罗尼"])
    ]

    public static var canonicalNames: [String] { aliases.map(\.0) }

    public static func lookupName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.components(separatedBy: CharacterSet(charactersIn: "(（")).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed
        func normalized(_ value: String) -> String {
            value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                .components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        }
        let key = normalized(base)
        let aliases = Self.aliases
        let canonical = aliases.first { _, values in values.contains { key == normalized($0) } }?.0 ?? base
        if let start = trimmed.firstIndex(where: { $0 == "(" || $0 == "（" }) {
            let annotation = String(trimmed[trimmed.index(after: start)...]).trimmingCharacters(in: CharacterSet(charactersIn: ")） "))
            let annotationKey = normalized(annotation)
            let translated = aliases.first { _, values in values.contains { annotationKey == normalized($0) } }?.0
            // Parenthesized translations and garnish notes are safe aliases. An explicit variant
            // must keep its own identity, including variants that are not in our alias dictionary.
            if let translated, normalized(translated) == normalized(canonical) { return canonical }
            if ["经典", "classic", "原版", "original"].contains(annotation.lowercased()) || ["加", "装饰", "我的", "推荐", "可选"].contains(where: { annotation.hasPrefix($0) }) { return canonical }
            if !annotation.isEmpty { return trimmed }
        }
        return canonical
    }

    /// Search keywords are separate from the stored name and never relax recipe identity matching.
    public static func imageSearchTerm(_ name: String) -> String {
        String(lookupName(name).components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: " ").prefix(100))
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
    case emptyName, incompleteRecipe
    public var errorDescription: String? {
        switch self {
        case .emptyName: "请填写鸡尾酒名称。"
        case .incompleteRecipe: "请填写材料和制作步骤，再收进配方册。用量可以保留原配方的写法。"
        }
    }
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
