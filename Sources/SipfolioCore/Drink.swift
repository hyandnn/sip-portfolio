import Foundation
import SwiftData

@Model
public final class Drink {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var category: String
    public var notes: String
    public var createdAt: Date
    public var usesOriginalPhoto: Bool
    public var tasteVariant: String? = nil
    public var bottleYear: String? = nil
    public var collectionDateOverride: Date? = nil

    public init(id: UUID = UUID(), name: String, category: String, notes: String = "", createdAt: Date = .now, usesOriginalPhoto: Bool = false, tasteVariant: String? = nil, bottleYear: String? = nil, collectionDate: Date? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.notes = notes
        self.createdAt = createdAt
        self.usesOriginalPhoto = usesOriginalPhoto
        self.tasteVariant = tasteVariant
        self.bottleYear = bottleYear
        self.collectionDateOverride = collectionDate
    }

    public var collectionDate: Date { collectionDateOverride ?? createdAt }
    public var variantDescription: String {
        [tasteVariant, bottleYear].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

public enum DrinkCategory: String, CaseIterable, Identifiable, Sendable {
    case whisky = "威士忌"
    case gin = "金酒"
    case rum = "朗姆酒"
    case vodka = "伏特加"
    case tequila = "龙舌兰"
    case brandy = "白兰地"
    case liqueur = "利口酒"
    case wine = "葡萄酒"
    case beer = "啤酒"
    case sake = "清酒"
    case baijiu = "白酒"
    case other = "其他"

    public var id: String { rawValue }
    public var symbol: String {
        switch self {
        case .wine: "wineglass"
        case .beer: "mug"
        case .sake, .baijiu: "cup.and.saucer"
        default: "wineglass.fill"
        }
    }
}

public enum SipfolioError: LocalizedError {
    case emptyName
    case duplicateName
    case invalidImage
    case imageTooLarge
    case noSubject
    case missingImage

    public var errorDescription: String? {
        switch self {
        case .emptyName: "请给这款酒起个名字。"
        case .duplicateName: "收藏册里已有相同酒名、口味和年份的酒款。可以编辑已有收藏，或补充口味与年份来区分。"
        case .invalidImage: "无法读取这张图片，请尝试 JPEG、PNG 或 HEIC 格式。"
        case .imageTooLarge: "照片超过 50 MB，请选择一张较小的图片。"
        case .noSubject: "没有找到清晰的前景。可以换一张背景更简单的照片，或使用原图收藏。"
        case .missingImage: "图片文件不存在，可能已被移动或删除。"
        }
    }
}
