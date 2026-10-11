import Foundation

public struct CocktailAmountPresentation: Sendable {
    public let text: String
    public let original: String
    public let usesRatio: Bool
}

public enum CocktailAmounts {
    /// Presentation only: the saved quantities and reference recipe are never rewritten.
    public static func presentation(_ ingredients: String) -> CocktailAmountPresentation {
        let lines = ingredients.components(separatedBy: .newlines)
        let parsed = lines.map { line -> (name: String, value: Double, dimension: String)? in
            let components = line.components(separatedBy: "—")
            guard components.count == 2 else { return nil }
            let name = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, let amount = volume(components[1]) else { return nil }
            return (name, amount.value, amount.dimension)
        }
        let quantities = parsed.compactMap { $0 }
        // Ranges and unsupported measured quantities must not silently become a partial ratio.
        let unsupportedMeasure = zip(lines, parsed).contains { line, amount in
            amount == nil && (line.localizedCaseInsensitiveContains("juice of") || line.range(of: #"\d.*(?:ml|cl|oz|毫升|盎司|tsp|tbsp|茶匙|汤匙|克|\bg\b)"#, options: [.regularExpression, .caseInsensitive]) != nil)
        }
        guard !unsupportedMeasure, quantities.count >= 2, Set(quantities.map(\.dimension)).count == 1, let minimum = quantities.map(\.value).min(), minimum > 0 else {
            return .init(text: ingredients, original: ingredients, usesRatio: false)
        }
        let normalized = quantities.map { $0.value / minimum }
        var ratios = normalized
        for denominator in 1...12 {
            let scaled = normalized.map { $0 * Double(denominator) }
            if scaled.allSatisfy({ abs($0 - $0.rounded()) < 0.005 }) {
                ratios = scaled.map { $0.rounded() }
                break
            }
        }
        var index = 0
        let text = zip(lines, parsed).map { line, amount in
            guard let amount else { return line }
            defer { index += 1 }
            let value = ratios[index].formatted(.number.locale(Locale(identifier: "en_US_POSIX")).precision(.fractionLength(0...2)))
            return "\(amount.name) — \(value) 份"
        }.joined(separator: "\n")
        return .init(text: text, original: ingredients, usesRatio: true)
    }

    private static func volume(_ text: String) -> (value: Double, dimension: String)? {
        let pattern = #"^\s*([0-9]+(?:\.[0-9]+)?(?:\s+[0-9]+/[0-9]+)?|[0-9]+/[0-9]+|[½¼¾⅓⅔])\s*(ml|cl|l|毫升|升|oz|fl\.?\s*oz\.?|ounces?|tsp|tbsp|teaspoons?|tablespoons?|份|parts?)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let numberRange = Range(match.range(at: 1), in: text), let unitRange = Range(match.range(at: 2), in: text),
              let number = number(String(text[numberRange])), number > 0 else { return nil }
        let unitName = text[unitRange].lowercased()
        if unitName == "份" || unitName.hasPrefix("part") { return (number, "parts") }
        let unit: UnitVolume
        switch unitName {
        case "ml", "毫升": unit = .milliliters
        case "cl": unit = .centiliters
        case "l", "升": unit = .liters
        case "tsp", "teaspoon", "teaspoons": unit = .teaspoons
        case "tbsp", "tablespoon", "tablespoons": unit = .tablespoons
        default: unit = .fluidOunces
        }
        return (Measurement(value: number, unit: unit).converted(to: .milliliters).value, "volume")
    }

    private static func number(_ text: String) -> Double? {
        let fractions: [String: Double] = ["½": 0.5, "¼": 0.25, "¾": 0.75, "⅓": 1.0/3, "⅔": 2.0/3]
        if let fraction = fractions[text] { return fraction }
        if let decimal = Double(text) { return decimal }
        let parts = text.split(whereSeparator: \.isWhitespace)
        guard let fraction = parts.last else { return nil }
        let values = fraction.split(separator: "/")
        guard values.count == 2, let top = Double(values[0]), let bottom = Double(values[1]), bottom > 0 else { return nil }
        let whole = parts.count == 2 ? Double(parts[0]) : 0
        return whole.map { $0 + top / bottom }
    }
}
