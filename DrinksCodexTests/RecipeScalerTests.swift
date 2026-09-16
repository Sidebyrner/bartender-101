import XCTest
@testable import DrinksCodex

final class RecipeScalerTests: XCTestCase {
    func testScalingMultipliesOzAmounts() {
        let drink = Drink.stub(ingredients: [
            Ingredient(name: "Gin", amountOz: 2, unit: .oz, dashCount: nil, approxCount: nil, spoonCount: nil),
            Ingredient(name: "Vermouth", amountOz: 1, unit: .oz, dashCount: nil, approxCount: nil, spoonCount: nil),
        ])
        let scaled = RecipeScaler.scaledIngredients(for: drink, servings: 2)
        XCTAssertEqual(scaled[0].amountOz, 4)
        XCTAssertEqual(scaled[1].amountOz, 2)
    }

    func testTopWithIngredientsDoNotScale() {
        // "Top with tonic" is a to-taste instruction, not a measured pour —
        // it should stay at its base amount no matter the servings count.
        let drink = Drink.stub(ingredients: [
            Ingredient(name: "Tonic water", amountOz: 4, unit: .topWith, dashCount: nil, approxCount: nil, spoonCount: nil),
        ])
        let scaled = RecipeScaler.scaledIngredients(for: drink, servings: 3)
        XCTAssertEqual(scaled[0].amountOz, 4)
        XCTAssertTrue(scaled[0].isImplicit)
    }

    func testDashCountsScaleAndRoundToWholeNumbers() {
        let drink = Drink.stub(ingredients: [
            Ingredient(name: "Bitters", amountOz: nil, unit: .dash, dashCount: 2, approxCount: nil, spoonCount: nil),
        ])
        XCTAssertEqual(RecipeScaler.scaledIngredients(for: drink, servings: 2)[0].dashCount, 4)
        // Never rounds down to zero dashes, even for a half-serving shot.
        XCTAssertEqual(RecipeScaler.scaledIngredients(for: drink, servings: 0.5)[0].dashCount, 1)
    }

    func testFormatPresetsAreEquivalentToTheirServingsMultiplier() {
        // Shot/Single/Double are convenience buttons for 0.5/1/2 servings,
        // not a separate recipe path — a "double" must always be exactly
        // twice the base pour, with no special-cased math anywhere.
        let drink = Drink.stub(ingredients: [
            Ingredient(name: "Tequila", amountOz: 2, unit: .oz, dashCount: nil, approxCount: nil, spoonCount: nil),
        ])
        XCTAssertEqual(RecipeScaler.scaledIngredients(for: drink, servings: 2)[0].amountOz, 4)
        XCTAssertEqual(RecipeScaler.scaledIngredients(for: drink, servings: 0.5)[0].amountOz, 1)
        XCTAssertEqual(RecipeScaler.scaledIngredients(for: drink, servings: 1)[0].amountOz, 2)
    }
}
