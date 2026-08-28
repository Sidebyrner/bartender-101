import Foundation
@testable import Bartender101

/// Minimal in-memory drink for scheduler/library tests that don't need a
/// real recipe — just a stable id and family to route through.
extension Drink {
    static func stub(
        id: String,
        family: DrinkFamily = .highball,
        tags: [DrinkTag] = [.well]
    ) -> Drink {
        Drink(
            id: id,
            name: id,
            family: family,
            glass: .highball,
            ice: .cubed,
            method: .build,
            difficulty: 1,
            tags: tags,
            ingredients: [Ingredient(name: "Test Spirit", amountOz: 2, unit: .oz, dashCount: nil, approxCount: nil, spoonCount: nil)],
            garnish: "None",
            notes: "Test fixture drink, not part of the real deck."
        )
    }
}
