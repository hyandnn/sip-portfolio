import Foundation

public enum CollectionSearch {
    /// Every keyword must occur in at least one field, allowing searches such as “金酒 2020”.
    public static func matches(_ query: String, fields: [String], cocktailName: String? = nil) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        var searchable = fields
        if let cocktailName { searchable.append(CocktailNames.lookupName(cocktailName)) }
        // Try the complete alias first: names such as “法式 75” contain spaces.
        if let cocktailName, CocktailNames.key(query) == CocktailNames.key(cocktailName) { return true }
        return query.split(whereSeparator: { $0.isWhitespace }).allSatisfy { keyword in
            let word = String(keyword)
            if searchable.contains(where: { $0.localizedStandardContains(word) }) { return true }
            guard let cocktailName else { return false }
            return CocktailNames.key(word) == CocktailNames.key(cocktailName)
        }
    }
}
