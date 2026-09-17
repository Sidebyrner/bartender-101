import Foundation

/// Groups logged drinks into bar nights. Pure functions with no storage or
/// SwiftUI dependency, so the grouping and totals are unit-tested
/// (`ShiftLogTests`) and port to a web build as-is.
enum ShiftLog {
    /// A bar night doesn't end at midnight: anything before this hour counts
    /// toward the previous evening's shift.
    static let rolloverHour = 4

    /// One night of logged drinks.
    struct Night: Identifiable, Hashable {
        /// Midnight at the start of the calendar day the shift began on.
        let date: Date
        /// Newest first.
        let entries: [MadeDrink]

        var id: Date { date }
        var drinkCount: Int { entries.count }
        var totalServings: Double { entries.reduce(0) { $0 + $1.servings } }
        var totalOz: Double { entries.reduce(0) { $0 + $1.totalOz } }
        var tally: [Tally] { ShiftLog.tally(entries) }
    }

    /// How many times one drink was made, most-made first.
    struct Tally: Identifiable, Hashable {
        let drinkID: String
        let drinkName: String
        let count: Int
        let servings: Double

        var id: String { drinkID }
    }

    /// The shift day a moment belongs to, as midnight of the day the shift
    /// began — 1:30 AM Saturday belongs to Friday night.
    static func shiftDay(for date: Date, calendar: Calendar = .current) -> Date {
        let shifted = calendar.date(byAdding: .hour, value: -rolloverHour, to: date) ?? date
        return calendar.startOfDay(for: shifted)
    }

    /// All nights with at least one drink, newest first.
    static func nights(from entries: [MadeDrink], calendar: Calendar = .current) -> [Night] {
        Dictionary(grouping: entries) { shiftDay(for: $0.madeAt, calendar: calendar) }
            .map { Night(date: $0.key, entries: $0.value.sorted { $0.madeAt > $1.madeAt }) }
            .sorted { $0.date > $1.date }
    }

    /// The night in progress at `now`, or `nil` if nothing's been logged yet.
    static func tonight(from entries: [MadeDrink], now: Date = Date(), calendar: Calendar = .current) -> Night? {
        let today = shiftDay(for: now, calendar: calendar)
        return nights(from: entries, calendar: calendar).first { $0.date == today }
    }

    /// Per-drink counts, most-made first, ties broken by name.
    static func tally(_ entries: [MadeDrink]) -> [Tally] {
        Dictionary(grouping: entries, by: \.drinkID)
            .map { id, made in
                Tally(
                    drinkID: id,
                    drinkName: made.max { $0.madeAt < $1.madeAt }?.drinkName ?? id,
                    count: made.count,
                    servings: made.reduce(0) { $0 + $1.servings }
                )
            }
            .sorted { $0.count == $1.count ? $0.drinkName < $1.drinkName : $0.count > $1.count }
    }

    /// Measured volume of a drink at a given scale: every oz-unit ingredient,
    /// plus batch water when batching. Matches what the recipe page shows.
    static func totalOz(for drink: Drink, servings: Double, batchMode: Bool) -> Double {
        let scaled = RecipeScaler.scaledIngredients(for: drink, servings: servings)
        let poured = scaled
            .filter { $0.unit == .oz }
            .compactMap(\.amountOz)
            .reduce(0, +)
        let water = batchMode ? Dilution.batchWaterOz(scaledIngredients: scaled, method: drink.method) : 0
        return poured + water
    }
}
