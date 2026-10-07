import Foundation

public struct DrinkKnowledge: Codable, Sendable, Equatable {
    public var name: String?
    public var category: String?
    public var confidence: String
    public var introduction: String
    public var flavors: [String]
    public var cocktails: [String]
    public var uncertainty: String
    public var generatedAt: Date
    public var model: String

    public init(name: String?, category: String?, confidence: String, introduction: String, flavors: [String], cocktails: [String], uncertainty: String = "", generatedAt: Date = .now, model: String = "deepseek-flash") {
        self.name = name; self.category = category; self.confidence = confidence
        self.introduction = introduction; self.flavors = flavors; self.cocktails = cocktails
        self.uncertainty = uncertainty; self.generatedAt = generatedAt; self.model = model
    }

    public var confidenceLabel: String {
        switch confidence {
        case "high": "标签较清晰，仍请核对"
        case "medium": "请核对酒名与版本"
        default: "信息不足，请手动确认"
        }
    }
}
