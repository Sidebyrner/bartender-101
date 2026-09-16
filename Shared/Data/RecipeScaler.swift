import Foundation

/// Resizes a drink's ingredient list to a given number of servings. Pure
/// input -> output with no SwiftUI or storage dependency, so the math is
/// unit-testable (`RecipeScalerTests`) and portable to a future web build
/// the same way `Scheduler` and `FuzzyMatch` are.
enum RecipeScaler {
    /// One ingredient after scaling — same shape as `Ingredient`, but every
    /// scalable quantity has already been multiplied by `servings`.
    struct ScaledIngredient: Identifiable, Hashable {
        var id: String { name }
        let name: String
        let amountOz: Double?
        let unit: IngredientUnit
        let dashCount: Int?
        let approxCount: Int?
        let spoonCount: Int?
        /// True for `topWith` ingredients, which don't scale with servings —
        /// "top with tonic" is a to-taste instruction, not a measured pour.
        let isImplicit: Bool

        /// Mirrors `Ingredient.countLabel` for the non-oz shorthand units,
        /// using the already-scaled counts.
        var countLabel: String? {
            if let dashCount { return dashCount == 1 ? "1 dash" : "\(dashCount) dashes" }
            if let approxCount { return "~\(approxCount)" }
            if let spoonCount { return spoonCount == 1 ? "1 barspoon" : "\(spoonCount) barspoons" }
            switch unit {
            case .topWith: return "Top with"
            case .rinse: return "Rinse"
            case .splash: return "Splash"
            case .muddled: return "Muddled"
            case .pinch: return "Pinch"
            case .optional: return "Optional"
            case .dash: return "Dash"
            case .barspoon: return "Barspoon"
            case .oz: return nil
            }
        }
    }

    /// Scales every ingredient in `drink` by `servings`. A `topWith`
    /// ingredient (soda, tonic) is left at its base amount regardless of
    /// `servings` — topping off is a to-taste instruction, not a measured
    /// pour that grows linearly with the rest of the drink.
    static func scaledIngredients(for drink: Drink, servings: Double) -> [ScaledIngredient] {
        drink.ingredients.map { ingredient in
            guard ingredient.unit != .topWith else {
                return ScaledIngredient(
                    name: ingredient.name,
                    amountOz: ingredient.amountOz,
                    unit: ingredient.unit,
                    dashCount: ingredient.dashCount,
                    approxCount: ingredient.approxCount,
                    spoonCount: ingredient.spoonCount,
                    isImplicit: true
                )
            }
            return ScaledIngredient(
                name: ingredient.name,
                amountOz: ingredient.amountOz.map { $0 * servings },
                unit: ingredient.unit,
                dashCount: ingredient.dashCount.map { scaledCount($0, servings: servings) },
                approxCount: ingredient.approxCount.map { scaledCount($0, servings: servings) },
                spoonCount: ingredient.spoonCount.map { scaledCount($0, servings: servings) },
                isImplicit: false
            )
        }
    }

    /// Scales a whole-number count (dashes, barspoons, muddled leaves) by
    /// `servings`, rounding to the nearest whole unit and never dropping
    /// below 1 — you can't pour half a dash.
    private static func scaledCount(_ count: Int, servings: Double) -> Int {
        max(1, Int((Double(count) * servings).rounded()))
    }
}
