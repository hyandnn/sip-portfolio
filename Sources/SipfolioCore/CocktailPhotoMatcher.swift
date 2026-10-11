import Foundation

/// Deterministic metadata matching. Image quality never compensates for a different drink.
public enum CocktailPhotoMatcher {
    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }
    private static func contains(_ text: String, phrase: String) -> Bool {
        (" " + normalized(text) + " ").contains(" " + normalized(phrase) + " ")
    }

    public static func score(_ candidate: CocktailPhotoCandidate, name: String) -> Int? {
        let target = CocktailNames.lookupName(name)
        let title = candidate.title + " " + (candidate.sourceTitle ?? "")
        let categories = (candidate.categories ?? []).map { $0.replacingOccurrences(of: "Category:", with: "") }
        let context = ([title] + categories).joined(separator: " ")
        let unwanted = ["sheet music", "advertisement", "bottle display", "illustration", "menu", "logo", "diagram", "poster", "painting", "drawing", "glassware"]
        guard !unwanted.contains(where: { contains(context, phrase: $0) }) else { return nil }

        // Reject a known different cocktail, including explicitly named variants of a classic.
        for other in CocktailNames.canonicalNames where CocktailNames.key(other) != CocktailNames.key(target) {
            if contains(title, phrase: other), !contains(target, phrase: other) { return nil }
        }
        for flavor in ["strawberry", "raspberry", "pineapple", "mango", "chocolate", "coconut", "frozen", "virgin", "草莓", "芒果", "椰子", "无酒精"] {
            if !contains(target, phrase: flavor), contains(title, phrase: flavor + " " + target) || contains(title, phrase: target + " " + flavor) { return nil }
        }

        var relevance = 0
        let titleMatches = contains(candidate.title, phrase: target) || CocktailNames.key(candidate.title) == CocktailNames.key(target)
        if categories.contains(where: { normalized($0) == normalized(target) }) { relevance = 100 }
        if titleMatches { relevance = max(relevance, 80) }
        if let sourceTitle = candidate.sourceTitle, contains(sourceTitle, phrase: target) { relevance = max(relevance, 90) }
        if CocktailNames.key(target) == "highball" {
            let whiskySoda = categories.contains { normalized($0) == "whisky soda" } || contains(title, phrase: "whisky soda") || contains(title, phrase: "whisky and soda")
            if whiskySoda {
                relevance = max(relevance, 100)
                if contains(title, phrase: "whisky soda") || contains(title, phrase: "whisky and soda") { relevance += 15 }
            }
            if contains(title, phrase: "highball glass") && !whiskySoda { return nil }
        }
        // Tags alone are insufficient: broad tags are the reason unrelated Flickr results leaked in.
        guard relevance >= 80 else { return nil }
        if relevance == 100 && titleMatches { relevance += 15 }
        let width = candidate.width ?? 0, height = candidate.height ?? 0
        let resolution = min(8, min(width, height) / 250)
        let portrait = height >= width && width > 0 ? 3 : 0
        let source = candidate.origin == .commons ? 2 : 0
        let mealScene = ["beef steak", "meal", "food platter", "restaurant interior"].contains { contains(title, phrase: $0) } ? 20 : 0
        return relevance + resolution + portrait + source - mealScene
    }

    public static func ranked(_ candidates: [CocktailPhotoCandidate], name: String) -> [CocktailPhotoCandidate] {
        var scored: [(candidate: CocktailPhotoCandidate, score: Int)] = []
        for candidate in candidates {
            if let value = score(candidate, name: name) { scored.append((candidate, value)) }
        }
        scored.sort { lhs, rhs in
            if lhs.score == rhs.score { return lhs.candidate.id < rhs.candidate.id }
            return lhs.score > rhs.score
        }
        return scored.map { $0.candidate }
    }
}
