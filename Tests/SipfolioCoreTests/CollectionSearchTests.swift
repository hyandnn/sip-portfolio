import Testing
@testable import SipfolioCore

@Test func collectionSearchCombinesKeywordsAcrossFields() {
    let fields = ["Hendrick’s Gin", "金酒", "佛手柑", "2020", "朋友送的"]
    #expect(CollectionSearch.matches("  gin  2020\n佛手柑 ", fields: fields))
    #expect(CollectionSearch.matches("朋友 金酒", fields: fields))
    #expect(!CollectionSearch.matches("gin 2021", fields: fields))
    #expect(CollectionSearch.matches(" \n ", fields: fields))
}

@Test func collectionSearchRecognizesCocktailAliasesAndAdditionalFields() {
    #expect(CollectionSearch.matches("纸飞机", fields: ["Paper Plane"], cocktailName: "Paper Plane"))
    #expect(CollectionSearch.matches("Paper Plane", fields: ["纸飞机"], cocktailName: "纸飞机"))
    #expect(CollectionSearch.matches("法式 75", fields: ["French 75"], cocktailName: "French 75"))
    #expect(CollectionSearch.matches("金汤力 黄瓜", fields: ["Gin & Tonic", "黄瓜片", "高球杯"], cocktailName: "Gin & Tonic"))
    #expect(CollectionSearch.matches("gin 高球杯", fields: ["Gin & Tonic", "高球杯"], cocktailName: "Gin & Tonic"))
    #expect(!CollectionSearch.matches("莫吉托", fields: ["Paper Plane"], cocktailName: "Paper Plane"))
    #expect(!CollectionSearch.matches("草莓莫吉托", fields: ["Mojito"], cocktailName: "Mojito"))
}
