import XCTest
@testable import DrinksCodex

final class DilutionTests: XCTestCase {
    func testPercentByMethod() {
        XCTAssertEqual(Dilution.percent(for: .stir), 0.25)
        XCTAssertEqual(Dilution.percent(for: .shake), 0.30)
        XCTAssertEqual(Dilution.percent(for: .muddle), 0.20)
        XCTAssertEqual(Dilution.percent(for: .build), 0)
        XCTAssertEqual(Dilution.percent(for: .blend), 0)
        XCTAssertEqual(Dilution.percent(for: .layer), 0)
    }

    func testBatchWaterOzUsesScaledLiquidVolume() {
        let drink = Drink.stub(method: .shake, ingredients: [
            Ingredient(name: "Gin", amountOz: 2, unit: .oz, dashCount: nil, approxCount: nil, spoonCount: nil),
            Ingredient(name: "Lemon juice", amountOz: 1, unit: .oz, dashCount: nil, approxCount: nil, spoonCount: nil),
            Ingredient(name: "Bitters", amountOz: nil, unit: .dash, dashCount: 2, approxCount: nil, spoonCount: nil),
        ])
        let scaled = RecipeScaler.scaledIngredients(for: drink, servings: 2)
        // (2 + 1) oz base, doubled to 6 oz of measured liquid; the dash has
        // no amountOz so it's excluded from the volume dilution is based on.
        XCTAssertEqual(Dilution.batchWaterOz(scaledIngredients: scaled, method: .shake), 1.8, accuracy: 0.0001)
    }

    func testNoBatchWaterForBuiltDrinks() {
        let drink = Drink.stub(method: .build, ingredients: [
            Ingredient(name: "Vodka", amountOz: 2, unit: .oz, dashCount: nil, approxCount: nil, spoonCount: nil),
        ])
        let scaled = RecipeScaler.scaledIngredients(for: drink, servings: 4)
        XCTAssertEqual(Dilution.batchWaterOz(scaledIngredients: scaled, method: .build), 0)
    }
}
