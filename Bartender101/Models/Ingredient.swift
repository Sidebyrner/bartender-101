import Foundation

/// The unit an ingredient's amount is measured in. Most are a plain volume
/// (`oz`); the rest describe bar shorthand that doesn't reduce to a single
/// number a jigger can measure (a "dash" varies by bottle, a "rinse" is
/// mostly discarded).
enum IngredientUnit: String, Codable, CaseIterable {
    case oz
    case topWith
    case dash
    case barspoon
    case rinse
    case splash
    case muddled
    case pinch
    case optional

    /// Whether this unit is normally paired with a positive `amountOz`.
    /// Kept in sync with `scripts/validate-drinks.js`'s AMOUNTLESS_UNITS.
    var expectsAmount: Bool {
        switch self {
        case .oz, .topWith, .splash: return true
        case .dash, .barspoon, .rinse, .muddled, .pinch, .optional: return false
        }
    }
}

/// One line of a drink's spec: what goes in, how much, and how it's measured.
struct Ingredient: Codable, Identifiable, Hashable {
    var id: String { name }

    let name: String
    /// Volume in ounces, when the unit is a measurable one. `nil` for things
    /// like a dash of bitters or a muddled lime that aren't jiggered.
    let amountOz: Double?
    let unit: IngredientUnit

    /// Optional display counts for non-volume units, e.g. "3 dashes",
    /// "8 mint leaves", "2 barspoons". Only one is ever populated per
    /// ingredient, matching whichever unit is set.
    let dashCount: Int?
    let approxCount: Int?
    let spoonCount: Int?

    /// A short human string for the ingredient line, e.g. "2 oz" or
    /// "3 dashes" or "Top with". Amount formatting (fractions, oz/ml) is
    /// handled by `Measure`; this only covers the non-oz shorthand units.
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
        case .oz: return nil
        }
    }
}
