import Foundation

/// Estimates the water a batched drink needs to make up for the dilution it
/// would normally pick up from being shaken or stirred to order. Batching N
/// servings ahead of time and serving them straight means skipping that
/// per-glass agitation, so a plain N x multiplier of the recipe tastes too
/// strong next to the same drink made one at a time.
///
/// The percentages below are a working bartending heuristic, not a physical
/// constant — isolated in this one enum specifically so they can be retuned
/// from real-world taste-testing without touching `RecipeScaler` or any view.
enum Dilution {
    /// Fraction of a batch's scaled liquid volume to add as water, keyed by
    /// how the drink is normally made. Built-to-order and blended drinks
    /// already get their dilution from the ice they're served over (or are
    /// ice themselves), so they take none.
    static func percent(for method: DrinkMethod) -> Double {
        switch method {
        case .stir: return 0.25
        case .shake: return 0.30
        case .muddle: return 0.20
        case .build, .blend, .layer: return 0
        }
    }

    /// The water (in oz) to add to a batch of `scaledIngredients` made with
    /// `method`, based on the total scaled liquid volume — every ingredient
    /// with a measured `amountOz`, `topWith` included.
    static func batchWaterOz(scaledIngredients: [RecipeScaler.ScaledIngredient], method: DrinkMethod) -> Double {
        let liquidOz = scaledIngredients.compactMap(\.amountOz).reduce(0, +)
        return liquidOz * percent(for: method)
    }
}
