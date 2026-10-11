import SwiftUI
import SipfolioCore

enum CollectionShelf: String, CaseIterable {
    case bottles = "藏酒屋"
    case photos = "杯中画"
    case text = "调酒笺"
}

struct CollectionShelfNavigation: View {
    @Binding var selection: CollectionShelf
    let bottleCount: Int
    let photoCount: Int
    let textCount: Int
    var body: some View {
        VStack(spacing: 7) {
            shelfButton(.bottles, count: bottleCount, subtitle: "酒瓶贴纸")
            shelfButton(.photos, count: photoCount, subtitle: "照片配方")
            shelfButton(.text, count: textCount, subtitle: "文字配方")
        }
    }
    private func shelfButton(_ shelf: CollectionShelf, count: Int, subtitle: String) -> some View {
        Button { selection = shelf } label: {
            HStack(spacing: 10) {
                if shelf == .bottles { PixelGlyph(kind: .bottle, size: 18) }
                else { Image(systemName: shelf == .photos ? "photo" : "text.alignleft").frame(width: 18) }
                VStack(alignment: .leading, spacing: 5) {
                    Text(shelf.rawValue).font(.pixel(size: 12))
                    Text(subtitle).font(.pixel(size: 10)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                Text(String(count)).font(.pixel(size: 10))
            }.padding(.horizontal, 11).padding(.vertical, 10)
                .foregroundStyle(selection == shelf ? Palette.purple : Palette.ink.opacity(0.7))
                .background(selection == shelf ? .white : .clear, in: PixelFrame(cornerRadius: 9))
                .overlay(PixelFrame(cornerRadius: 9).strokeBorder(selection == shelf ? Palette.ink.opacity(0.65) : .clear, lineWidth: 2).allowsHitTesting(false))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(shelf.rawValue)
            .accessibilityAddTraits(selection == shelf ? .isSelected : [])
    }
}

struct CocktailTextCard: View {
    let recipe: CocktailRecipe
    let action: () -> Void
    private var accent: Color {
        let colors = [Palette.purple, Color(red: 0.26, green: 0.46, blue: 0.37), Color(red: 0.60, green: 0.34, blue: 0.23), Color(red: 0.28, green: 0.43, blue: 0.60)]
        let index = CocktailNames.key(recipe.name).unicodeScalars.reduce(0) { $0 + Int($1.value) } % colors.count
        return colors[index]
    }
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("THE RECIPE MENU").font(.pixel(size: 10)).tracking(1)
                    Spacer()
                    PixelGlyph(kind: .sparkle, size: 18)
                }.foregroundStyle(accent)
                Text(recipe.name).font(.system(size: 29, weight: .bold, design: .serif)).italic()
                    .foregroundStyle(accent).lineLimit(3).minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
                Rectangle().fill(accent).frame(height: 3).allowsHitTesting(false)
                Text(CocktailAmounts.presentation(recipe.ingredients).text).font(.pixel(size: 12)).foregroundStyle(Palette.ink).lineLimit(5)
                    .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
                Text(recipe.steps).font(.pixel(size: 11)).foregroundStyle(Palette.muted).lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)
                Spacer(minLength: 0)
                HStack {
                    Text(recipe.glass.isEmpty ? "一杯自己的调配记忆" : recipe.glass).font(.pixel(size: 10)).lineLimit(1)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }.foregroundStyle(accent)
            }.padding(22).frame(maxWidth: .infinity, minHeight: 398, alignment: .topLeading)
                .background(accent.opacity(0.055), in: PixelFrame(cornerRadius: 15))
                .overlay(PixelFrame(cornerRadius: 15).strokeBorder(accent.opacity(0.6), lineWidth: 2).allowsHitTesting(false))
                .shadow(color: accent.opacity(0.15), radius: 0, x: 4, y: 4)
                .contentShape(PixelFrame(cornerRadius: 15))
        }.buttonStyle(.plain).accessibilityLabel("\(recipe.name)，查看文字配方")
    }
}
