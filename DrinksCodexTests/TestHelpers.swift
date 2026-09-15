import Foundation
@testable import DrinksCodex

/// Minimal in-memory drink for scaling/dilution tests that don't need a
/// real recipe — just an ingredient list to route through the math.
extension Drink {
    static func stub(
        id: String = "test-drink",
        family: DrinkFamily = .highball,
        method: DrinkMethod = .build,
        ingredients: [Ingredient] = [
            Ingredient(name: "Test Spirit", amountOz: 2, unit: .oz, dashCount: nil, approxCount: nil, spoonCount: nil)
        ]
    ) -> Drink {
        Drink(
            id: id,
            name: id,
            family: family,
            glass: .highball,
            ice: .cubed,
            method: method,
            difficulty: 1,
            tags: [.well],
            ingredients: ingredients,
            garnish: "None",
            notes: "Test fixture drink, not part of the real deck."
        )
    }
}
