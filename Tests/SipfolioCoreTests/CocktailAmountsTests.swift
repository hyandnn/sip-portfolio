import Testing
@testable import SipfolioCore

@Test
func volumeAmountsBecomeSimpleRatiosWithoutChangingRecipe() {
    let original = "金酒 — 15 ml\n汤力水 — 45 ml\n冰块 — 适量\n青柠 — 1"
    let display = CocktailAmounts.presentation(original)
    #expect(display.usesRatio)
    #expect(display.text == "金酒 — 1 份\n汤力水 — 3 份\n冰块 — 适量\n青柠 — 1")
    #expect(display.original == original)
    #expect(CocktailAmounts.presentation("金酒 — 30 ml\n味美思 — 45 ml").text == "金酒 — 2 份\n味美思 — 3 份")
    #expect(CocktailAmounts.presentation("金酒 — 1 份\n汤力水 — 3 份").text == "金酒 — 1 份\n汤力水 — 3 份")
}

@Test
func ratioPresentationHandlesFractionsUnitsAndUnconvertibleAmounts() {
    #expect(CocktailAmounts.presentation("Gin — 1 1/2 oz\nVermouth — 1/2 oz").text == "Gin — 3 份\nVermouth — 1 份")
    #expect(CocktailAmounts.presentation("Gin — ½ oz\nTonic — 1 oz").text == "Gin — 1 份\nTonic — 2 份")
    #expect(CocktailAmounts.presentation("金酒 — 3 cl\n汤力水 — 90 ml").text == "金酒 — 1 份\n汤力水 — 3 份")
    for original in ["金酒 — 45 ml\n冰块 — 适量", "金酒 — 1 份\n汤力水 — 45 ml", "金酒 — 45 ml\n汤力水 — 100–120 ml", "金酒 — 15 ml\n柠檬汁 — 30 ml\n糖浆 — 5–10 ml", "柠檬 — 1\n冰块 — 适量"] {
        let display = CocktailAmounts.presentation(original)
        #expect(!display.usesRatio && display.text == original)
    }
    let fruit = "Rum — 1 1/2 oz\nLime — Juice of 1/2\nSugar — 1 tsp"
    #expect(CocktailAmounts.presentation(fruit).text == fruit)
}
