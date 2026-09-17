import XCTest
@testable import Bartender101

/// Pour order is what a bartender reads top to bottom mid-shift, so a wrong
/// order is a real mistake behind the bar, not just a cosmetic one.
@MainActor
final class PourOrderTests: XCTestCase {
    private func names(for id: String) throws -> [String] {
        let drink = try XCTUnwrap(try DrinkLibrary.loadDrinks().first { $0.id == id })
        let scaled = RecipeScaler.scaledIngredients(for: drink, servings: 1)
        return PourOrder.ordered(scaled, method: drink.method).map(\.ingredient.name)
    }

    func testSourPoursCheapestFirst() throws {
        XCTAssertEqual(try names(for: "margarita"), ["Lime juice", "Triple sec", "Blanco tequila"])
    }

    func testMuddledFirstAndToppedLast() throws {
        let order = try names(for: "mojito")
        XCTAssertEqual(order.first, "Mint leaves")
        XCTAssertEqual(order.last, "Soda water")
    }

    func testBittersBeforeSyrupBeforeSpirit() throws {
        XCTAssertEqual(try names(for: "old-fashioned"), ["Angostura bitters", "Simple syrup", "Bourbon or rye"])
    }

    func testLayeredDrinkKeepsSpecOrder() throws {
        XCTAssertEqual(try names(for: "b-52"), ["Coffee liqueur", "Irish cream", "Orange liqueur"])
    }

    func testRinseIsAGlassStep() {
        XCTAssertEqual(PourOrder.stage(name: "Absinthe", unit: .rinse), .glass)
    }

    func testCreamFloatsLastInBuiltDrinks() {
        let drink = Drink.stub(method: .build, ingredients: [
            Ingredient(name: "Heavy cream", amountOz: 1, unit: .oz, dashCount: nil, approxCount: nil, spoonCount: nil),
            Ingredient(name: "Vodka", amountOz: 2, unit: .oz, dashCount: nil, approxCount: nil, spoonCount: nil),
        ])
        let order = PourOrder.ordered(RecipeScaler.scaledIngredients(for: drink, servings: 1), method: .build)
        XCTAssertEqual(order.map(\.ingredient.name), ["Vodka", "Heavy cream"])
    }

    func testTiesKeepSpecOrder() {
        let spirits = ["Vodka", "Gin", "White rum", "Blanco tequila"]
        let drink = Drink.stub(method: .shake, ingredients: spirits.map {
            Ingredient(name: $0, amountOz: 0.5, unit: .oz, dashCount: nil, approxCount: nil, spoonCount: nil)
        })
        let order = PourOrder.ordered(RecipeScaler.scaledIngredients(for: drink, servings: 1), method: .shake)
        XCTAssertEqual(order.map(\.ingredient.name), spirits)
    }

    func testGinDoesNotMatchGinger() {
        XCTAssertEqual(PourOrder.stage(name: "Honey-ginger syrup", unit: .oz), .mixer)
    }

    /// Every ingredient in the deck must hit a deliberate rule. A new drink
    /// with an unrecognized ingredient fails here instead of silently landing
    /// in the fallback slot.
    func testEveryDeckIngredientIsClassified() throws {
        let unclassified = try DrinkLibrary.loadDrinks()
            .flatMap(\.ingredients)
            .filter { PourOrder.classify(name: $0.name, unit: $0.unit) == nil }
            .map { "\($0.name) [\($0.unit.rawValue)]" }
        XCTAssertEqual(Set(unclassified), [], "add these to PourOrder's word lists")
    }
}
