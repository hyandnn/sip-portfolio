import SwiftUI
import SipfolioCore
import CoreText

enum PixelTypography {
    static let fontName: String = {
        guard let url = Bundle.module.url(forResource: "fusion-pixel-12px-proportional-zh_hans", withExtension: "otf", subdirectory: "Resources/Fonts") else { return "Menlo" }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor], let first = descriptors.first else { return "Menlo" }
        return CTFontCopyPostScriptName(CTFontCreateWithFontDescriptor(first, 12, nil)) as String
    }()
}

extension Font {
    static func pixel(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        // Integer sizes keep the pixel outlines clear; long Chinese recipes remain readable.
        .custom(PixelTypography.fontName, fixedSize: size >= 20 ? 24 : 12)
    }
}

struct PixelFrame: InsettableShape {
    var cornerRadius: CGFloat = 12
    var insetAmount: CGFloat = 0
    func path(in bounds: CGRect) -> Path {
        let r = bounds.insetBy(dx: insetAmount, dy: insetAmount)
        guard r.width > 0, r.height > 0 else { return Path() }
        let s = min(max(2, (cornerRadius / 3).rounded()), min(r.width, r.height) / 4)
        let x = r.minX, y = r.minY, w = r.width, h = r.height
        let points: [CGPoint] = [
            .init(x: x+2*s, y: y), .init(x: x+w-2*s, y: y), .init(x: x+w-2*s, y: y+s),
            .init(x: x+w-s, y: y+s), .init(x: x+w-s, y: y+2*s), .init(x: x+w, y: y+2*s),
            .init(x: x+w, y: y+h-2*s), .init(x: x+w-s, y: y+h-2*s), .init(x: x+w-s, y: y+h-s),
            .init(x: x+w-2*s, y: y+h-s), .init(x: x+w-2*s, y: y+h), .init(x: x+2*s, y: y+h),
            .init(x: x+2*s, y: y+h-s), .init(x: x+s, y: y+h-s), .init(x: x+s, y: y+h-2*s),
            .init(x: x, y: y+h-2*s), .init(x: x, y: y+2*s), .init(x: x+s, y: y+2*s),
            .init(x: x+s, y: y+s), .init(x: x+2*s, y: y+s)
        ]
        return Path { path in path.addLines(points); path.closeSubpath() }
    }
    func inset(by amount: CGFloat) -> some InsettableShape {
        var copy = self; copy.insetAmount += amount; return copy
    }
}

struct PixelPaper: View {
    var body: some View {
        Canvas { context, size in
            for y in stride(from: 12.0, to: size.height, by: 24) {
                for x in stride(from: 12.0, to: size.width, by: 24) {
                    context.fill(Path(CGRect(x: x, y: y, width: 2, height: 2)), with: .color(Palette.ink.opacity(0.04)))
                }
            }
        }.background(Palette.paper).allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct PixelGlyph: View {
    enum Kind { case bottle, glass, sparkle, plus, search, settings, arrow }
    let kind: Kind
    var size: CGFloat = 20
    private var rows: [String] {
        switch kind {
        case .bottle: ["000111000", "000101000", "000101000", "001111100", "011000110", "010111010", "010101010", "010111010", "011111110"]
        case .glass: ["111111111", "010000010", "001000100", "000101000", "000010000", "000010000", "000010000", "000010000", "001111100"]
        case .sparkle: ["000010000", "000010000", "000111000", "001111100", "111111111", "001111100", "000111000", "000010000", "000010000"]
        case .plus: ["000000000", "000110000", "000110000", "011111110", "011111110", "000110000", "000110000", "000000000", "000000000"]
        case .search: ["001111000", "010000100", "100000010", "100000010", "010000100", "001111000", "000000100", "000000010", "000000001"]
        case .settings: ["010000010", "010111010", "111101111", "010111010", "010000010", "010000010", "111010111", "010010010", "010000010"]
        case .arrow: ["001111110", "000000110", "000001010", "000010010", "000100010", "001000000", "010000000", "000000000", "000000000"]
        }
    }
    var body: some View {
        Canvas { context, bounds in
            let unit = max(1, floor(min(bounds.width, bounds.height) / 9))
            let origin = CGPoint(x: floor((bounds.width - unit * 9) / 2), y: floor((bounds.height - unit * 9) / 2))
            for (y, row) in rows.enumerated() {
                for (x, value) in row.enumerated() where value == "1" {
                    context.fill(Path(CGRect(x: origin.x + CGFloat(x)*unit, y: origin.y + CGFloat(y)*unit, width: unit, height: unit)), with: .foreground)
                }
            }
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

enum Palette {
    static let ink = Color(red: 0.16, green: 0.25, blue: 0.22)
    static let muted = Color(red: 0.37, green: 0.43, blue: 0.36)
    static let paper = Color(red: 0.99, green: 0.97, blue: 0.91)
    static let sidebar = Color(red: 0.92, green: 0.94, blue: 0.85)
    static let purple = Color(red: 0.48, green: 0.30, blue: 0.52)
    static let line = ink.opacity(0.26)
    static let mint = Color(red: 0.71, green: 0.85, blue: 0.69)

    static func color(for category: String) -> Color {
        switch DrinkCategory(rawValue: category) {
        case .whisky, .brandy: Color(red: 0.98, green: 0.88, blue: 0.70)
        case .gin, .sake: Color(red: 0.81, green: 0.90, blue: 0.83)
        case .rum, .liqueur: Color(red: 0.97, green: 0.81, blue: 0.78)
        case .vodka, .beer: Color(red: 0.81, green: 0.88, blue: 0.96)
        case .tequila, .baijiu: Color(red: 0.91, green: 0.91, blue: 0.75)
        default: Color(red: 0.88, green: 0.83, blue: 0.97)
        }
    }
}

struct PrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pixel(size: 13, weight: .semibold))
            .padding(.horizontal, 20).padding(.vertical, 12)
            .foregroundStyle(.white)
            .background(Palette.purple, in: PixelFrame(cornerRadius: 8))
            .overlay(PixelFrame(cornerRadius: 8).strokeBorder(Palette.ink, lineWidth: 2))
            .shadow(color: Palette.ink.opacity(enabled ? 0.65 : 0.1), radius: 0, x: configuration.isPressed ? 0 : 3, y: configuration.isPressed ? 0 : 3)
            .offset(x: configuration.isPressed ? 2 : 0, y: configuration.isPressed ? 2 : 0)
            .opacity(enabled ? 1 : 0.5)
            .contentShape(PixelFrame(cornerRadius: 8))
    }
}

struct PixelSecondaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.pixel(size: 12))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Palette.sidebar, in: PixelFrame(cornerRadius: 6))
            .overlay(PixelFrame(cornerRadius: 6).strokeBorder(Palette.ink.opacity(0.45)))
            .opacity(enabled ? 1 : 0.5)
            .offset(y: configuration.isPressed ? 1 : 0)
    }
}

struct PixelTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration.textFieldStyle(.plain).font(.pixel(size: 12)).padding(9)
            .background(.white, in: PixelFrame(cornerRadius: 8))
            .overlay(PixelFrame(cornerRadius: 8).strokeBorder(Palette.line))
    }
}

struct CategoryBadge: View {
    let category: String
    var body: some View {
        Text(category).font(.pixel(size: 10, weight: .semibold))
            .foregroundStyle(Palette.ink.opacity(0.75))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Palette.color(for: category), in: PixelFrame(cornerRadius: 4))
            .overlay(PixelFrame(cornerRadius: 4).strokeBorder(Palette.ink.opacity(0.2)))
    }
}

struct CategoryInput: View {
    @Binding var selection: String
    var history: [String] = []
    @FocusState private var focused: Bool
    private var suggestions: [String] {
        Array(CategoryHistory.suggestions(from: history, matching: selection).filter { $0 != selection }.prefix(5))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            TextField("AI 识别或输入，如蜂蜜酒", text: $selection)
                .textFieldStyle(.plain).font(.pixel(size: 12)).padding(11)
                .background(.white, in: PixelFrame(cornerRadius: 8))
                .overlay(PixelFrame(cornerRadius: 8).stroke(Palette.line))
                .focused($focused).accessibilityLabel("酒类")
            if focused && !suggestions.isEmpty {
                Text("用过的类别").font(.pixel(size: 9)).foregroundStyle(Palette.muted)
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(suggestions, id: \.self) { category in
                            Button(category) { selection = category }
                                .buttonStyle(.plain).font(.pixel(size: 10))
                                .padding(.horizontal, 9).padding(.vertical, 5)
                                .background(Palette.purple.opacity(0.08), in: PixelFrame(cornerRadius: 4))
                        }
                    }
                }.scrollIndicators(.hidden)
            }
        }
    }
}

struct PhotoView: View {
    let data: Data?
    var contentMode: ContentMode = .fit
    var body: some View {
        if let data, let image = NSImage(data: data) {
            if contentMode == .fill {
                GeometryReader { geometry in
                    Image(nsImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                }
            } else { Image(nsImage: image).resizable().scaledToFit() }
        } else {
            Image(systemName: "photo").font(.pixel(size: 32, weight: .light)).foregroundStyle(Palette.muted)
        }
    }
}

struct StoredPhoto: View {
    let url: URL
    var contentMode: ContentMode = .fit
    @State private var data: Data?
    var body: some View {
        PhotoView(data: data, contentMode: contentMode)
            .task(id: url) {
                let imageURL = url
                data = await Task.detached(priority: .userInitiated) { try? Data(contentsOf: imageURL) }.value
            }
    }
}

// Decorative bottles in the empty state are shapes, never saved as real collection entries.
struct BottleIllustration: View {
    var color: Color
    var label: String
    var squat = false
    var body: some View {
        VStack(spacing: 0) {
            PixelFrame(cornerRadius: 3).fill(Palette.ink).frame(width: 23, height: 12)
            Rectangle().fill(color).frame(width: 20, height: 28).overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
            ZStack {
                PixelFrame(cornerRadius: 14)
                    .fill(color)
                    .overlay(PixelFrame(cornerRadius: 14).strokeBorder(Palette.ink, lineWidth: 3))
                    .overlay(alignment: .leading) {
                        Rectangle().fill(.white.opacity(0.35)).frame(width: 6, height: 60).padding(.leading, 9)
                    }
                VStack(spacing: 5) {
                    PixelGlyph(kind: .sparkle, size: 18)
                    Text(label).font(.pixel(size: 9, weight: .black, design: .serif)).tracking(1).lineLimit(1).minimumScaleFactor(0.65)
                    Rectangle().fill(Palette.ink.opacity(0.2)).frame(width: 30, height: 1)
                }.foregroundStyle(Palette.ink)
                    .frame(width: squat ? 61 : 48, height: 62)
                    .background(Color(red: 1, green: 0.97, blue: 0.89), in: PixelFrame(cornerRadius: 3))
            }.frame(width: squat ? 86 : 68, height: squat ? 103 : 136)
        }
        .shadow(color: .white, radius: 0, x: 4, y: 0)
        .shadow(color: .white, radius: 0, x: -4, y: 0)
        .shadow(color: .white, radius: 0, x: 0, y: 4)
        .shadow(color: .white, radius: 0, x: 0, y: -4)
        .shadow(color: Palette.ink.opacity(0.18), radius: 0, x: 4, y: 4)
        .accessibilityHidden(true)
    }
}
