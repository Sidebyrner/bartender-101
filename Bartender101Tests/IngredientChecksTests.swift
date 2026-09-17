import XCTest
@testable import Bartender101

final class IngredientChecksTests: XCTestCase {
    private let index = IngredientIndex(entries: (try? IngredientIndex.loadBundled()) ?? [])

    private func issue(_ ingredient: Ingredient) -> IngredientChecks.UnitIssue? {
        IngredientChecks.unitIssue(for: ingredient, category: index.resolve(ingredient.name)?.category)
    }

    func testBittersInOunces() {
        let problem = issue(Ingredient("Angostura bitters", oz: 2))
        XCTAssertEqual(problem?.fix, Ingredient("Angostura bitters", unit: .dash, dashes: 2))
        XCTAssertNil(issue(Ingredient("Angostura bitters", oz: 1.5)), "the Trinidad Sour is a real spec")
        XCTAssertNil(issue(Ingredient("Angostura bitters", unit: .dash, dashes: 3)))
    }

    func testSpiritAsATop() {
        XCTAssertEqual(issue(Ingredient("Gin", oz: 2, unit: .topWith))?.fix, Ingredient("Gin", oz: 2))
        XCTAssertEqual(issue(Ingredient("Campari", oz: 1, unit: .splash))?.fix, Ingredient("Campari", oz: 0.5))
        XCTAssertNotNil(issue(Ingredient("Vodka", oz: 5)))
        XCTAssertNil(issue(Ingredient("Vodka", oz: 5))?.fix, "a big pour is a heads-up, not an auto-fix")
    }

    func testMixersHerbsAndCitrus() {
        XCTAssertEqual(issue(Ingredient("Soda water", unit: .dash, dashes: 2))?.fix, Ingredient("Soda water", oz: 4, unit: .topWith))
        XCTAssertEqual(issue(Ingredient("Mint leaves", oz: 1))?.fix, Ingredient("Mint leaves", unit: .muddled, approx: 4))
        XCTAssertEqual(issue(Ingredient("Lime juice", oz: 2, unit: .topWith))?.fix, Ingredient("Lime juice", oz: 0.75))
        XCTAssertNotNil(issue(Ingredient("Lemon juice", oz: 4)))
        XCTAssertNil(IngredientChecks.unitIssue(for: Ingredient("Mystery", oz: 9, unit: .topWith), category: nil))
    }

    /// No rule fires on anything in the deck.
    @MainActor
    func testNoFalseAlarmsOnDeck() throws {
        var flagged: [String] = []
        for drink in try DrinkLibrary.loadDrinks() {
            for ingredient in drink.ingredients where issue(ingredient) != nil {
                flagged.append("\(drink.name): \(ingredient.name)")
            }
            if !IngredientChecks.duplicateGroups(in: drink.ingredients, index: index).isEmpty {
                flagged.append("\(drink.name): duplicate")
            }
        }
        XCTAssertEqual(flagged, [])
    }

    func testDuplicatesMatchAcrossAliases() {
        let lines = [
            Ingredient("Angostura", unit: .dash, dashes: 2),
            Ingredient("Gin", oz: 2),
            Ingredient("Angostura bitters", unit: .dash, dashes: 1),
            Ingredient("Base spirit", oz: 1),
            Ingredient("base spirit", oz: 1),
            Ingredient("House tincture", unit: .dash, dashes: 1),
            Ingredient("house tincture", unit: .dash, dashes: 1),
        ]
        XCTAssertEqual(IngredientChecks.duplicateGroups(in: lines, index: index), [[0, 2], [5, 6]])
    }

    func testCombine() {
        XCTAssertEqual(IngredientChecks.combine(Ingredient("Lime juice", oz: 0.5), Ingredient("Lime juice", oz: 0.25)),
                       Ingredient("Lime juice", oz: 0.75))
        XCTAssertEqual(IngredientChecks.combine(Ingredient("Angostura bitters", unit: .dash, dashes: 2),
                                                Ingredient("Angostura", unit: .dash, dashes: 1)),
                       Ingredient("Angostura bitters", unit: .dash, dashes: 3))
        XCTAssertFalse(IngredientChecks.canCombine(Ingredient("Lime juice", oz: 1), Ingredient("Lime juice", unit: .muddled)))
    }
}
