import Foundation
@testable import Bartender101

/// Minimal in-memory drink for tests that don't need a real recipe — a
/// stable id, family, and tags for scheduler/library tests, or a method and
/// ingredient list for scaling/dilution math.
extension Drink {
    static func stub(
        id: String = "test-drink",
        family: DrinkFamily = .highball,
        method: DrinkMethod = .build,
        tags: [DrinkTag] = [.well],
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
            tags: tags,
            ingredients: ingredients,
            garnish: "None",
            notes: "Test fixture drink, not part of the real deck."
        )
    }
}
