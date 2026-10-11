import Foundation
import Testing
@testable import SipfolioCore

private func candidate(_ title: String, filename: String? = nil, categories: [String] = [], width: Int = 1200, height: Int = 1600) -> CocktailPhotoCandidate {
    .init(title: title, imageURL: URL(string: "https://upload.wikimedia.org/wikipedia/commons/a/ab/\(UUID()).jpg")!, pageURL: URL(string: "https://commons.wikimedia.org/wiki/File:Example.jpg")!, credit: "Author", license: "CC BY 4.0", licenseURL: URL(string: "https://creativecommons.org/licenses/by/4.0/")!, origin: .commons, sourceTitle: filename, categories: categories, width: width, height: height)
}

@Test func photoMatcherRejectsHighballGlassAndUnrelatedArt() {
    for title in ["Gin and Tonic cocktail in highball glass", "Mojito", "30,000 views - thank you all", "Highball glass with ice", "Friend Highball sheet music cover", "Highball whisky bottle display"] {
        #expect(CocktailPhotoMatcher.score(candidate(title), name: "Highball") == nil)
    }
    #expect(CocktailPhotoMatcher.score(candidate("Japanese whisky soda", categories: ["Category:Whisky soda"]), name: "Highball") != nil)
    #expect(CocktailPhotoMatcher.score(candidate("Whisky and Soda"), name: "高球") != nil)
}

@Test func photoMatcherPrefersTopicIdentityBeforeResolutionAndKeepsVariantsSeparate() throws {
    let accurate = candidate("Paper Plane cocktail", categories: ["Category:Paper Plane"], width: 800, height: 1100)
    let attractiveButWrong = candidate("Mojito", width: 5000, height: 6000)
    let smaller = candidate("Paper Plane cocktail", width: 300, height: 300)
    let ranked = CocktailPhotoMatcher.ranked([attractiveButWrong, smaller, accurate], name: "纸飞机")
    #expect(ranked.map(\.id) == [accurate.id, smaller.id])
    #expect(CocktailPhotoMatcher.score(candidate("Espresso Martini"), name: "Martini") == nil)
    #expect(CocktailPhotoMatcher.score(candidate("Strawberry Mojito"), name: "Mojito") == nil)
    #expect(CocktailPhotoMatcher.score(candidate("Mojito"), name: "Mojito（草莓）") == nil)
    #expect(CocktailPhotoMatcher.score(candidate("Negroni Sbagliato"), name: "Negroni") == nil)
    #expect(CocktailPhotoMatcher.score(candidate("Espresso Martini"), name: "浓缩咖啡马提尼") != nil)
}

@Test func photoCandidatesDecodeLegacyMetadata() throws {
    let photo = candidate("Paper Plane")
    var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(photo)) as? [String: Any])
    for key in ["sourceTitle", "categories", "tags", "width", "height"] { json[key] = nil }
    let legacy = try JSONDecoder().decode(CocktailPhotoCandidate.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(legacy.width == nil && CocktailPhotoMatcher.score(legacy, name: "纸飞机") != nil)
}
