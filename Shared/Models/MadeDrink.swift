import Foundation

/// One drink logged with the recipe page's "Made it" button, with the scale
/// settings on screen at the moment it was made — so a night's log shows
/// not just *what* was made but *how much* (a double, a pitcher batch).
struct MadeDrink: Codable, Identifiable, Hashable {
    let id: UUID
    let drinkID: String
    /// Stored alongside the id so the log still reads correctly if a drink
    /// is later renamed or removed from the deck.
    let drinkName: String
    let madeAt: Date
    let servings: Double
    let batchMode: Bool
    let unit: MeasurementUnit
    /// Total measured volume (oz-unit ingredients plus any batch water) at
    /// the logged servings. Dashes, tops, and muddled items aren't counted.
    let totalOz: Double
}
