import Foundation

/// Every ingredient the builder's picker offers: the bundled catalog, names
/// used in house drinks that the catalog doesn't know, and ingredients the
/// user added from the picker. Also learns from the deck — how many drinks
/// use each ingredient, and the unit and amount they most often use it at —
/// so picking one fills in a sensible pour.
///
/// User-added ingredients and recents persist as one JSON file in
/// Application Support, like `CustomDrinkStore`.
@MainActor
final class IngredientCatalog: ObservableObject {
    @Published private(set) var index: IngredientIndex
    @Published private(set) var customIngredients: [CatalogIngredient] = []
    /// Most recent first.
    @Published private(set) var recentIDs: [String] = []

    static let recentLimit = 12

    private let bundled: [CatalogIngredient]
    private var houseEntries: [CatalogIngredient] = []
    private var usage: [String: Int] = [:]
    private var deckDefaults: [String: IngredientDefault] = [:]
    private let fileURL: URL

    private struct Saved: Codable {
        var customIngredients: [CatalogIngredient]
        var recentIDs: [String]
    }

    init(bundled: [CatalogIngredient]? = nil, fileURL: URL? = nil) {
        self.bundled = bundled ?? IngredientIndex.bundled.entries
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.index = IngredientIndex(entries: self.bundled)
        load()
        rebuild()
    }

    private static func defaultFileURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("custom_ingredients.json")
    }

    // MARK: - Learning from drinks

    /// Counts how often the deck uses each ingredient and at what pour.
    func learn(fromDeck deck: [Drink]) {
        var counts: [String: Int] = [:]
        var pours: [String: [IngredientDefault: Int]] = [:]
        for drink in deck {
            for ingredient in drink.ingredients {
                guard let entry = index.resolve(ingredient.name) else { continue }
                counts[entry.id, default: 0] += 1
                let pour = IngredientDefault(
                    unit: ingredient.unit,
                    amountOz: ingredient.unit.expectsAmount ? ingredient.amountOz : nil,
                    count: ingredient.dashCount ?? ingredient.approxCount ?? ingredient.spoonCount
                )
                pours[entry.id, default: [:]][pour, default: 0] += 1
            }
        }
        usage = counts
        deckDefaults = pours.compactMapValues { tally in
            tally.max { lhs, rhs in
                lhs.value != rhs.value ? lhs.value < rhs.value : (lhs.key.amountOz ?? 0) > (rhs.key.amountOz ?? 0)
            }?.key
        }
        objectWillChange.send()
    }

    /// Makes names typed into older house drinks pickable, guessing a
    /// category from `DrinkBalance`'s word lists.
    func learn(fromHouseDrinks drinks: [CustomDrink]) {
        var seen = Set<String>()
        let known = IngredientIndex(entries: bundled + customIngredients)
        houseEntries = drinks.flatMap(\.ingredients).compactMap { ingredient in
            let name = ingredient.name.trimmingCharacters(in: .whitespaces)
            let key = IngredientIndex.normalize(name)
            guard !key.isEmpty, DrinkTemplates.placeholderCategory(for: name) == nil,
                  known.resolve(name) == nil,
                  seen.insert(key).inserted else { return nil }
            return CatalogIngredient(
                id: CatalogIngredient.customID(for: name),
                name: name,
                category: Self.guessCategory(name: name, unit: ingredient.unit)
            )
        }
        rebuild()
    }

    static func guessCategory(name: String, unit: IngredientUnit) -> IngredientCategory {
        switch DrinkBalance.wordListRole(name: name, unit: unit) {
        case .spirit: return .spirits
        case .modifier: return .liqueurs
        case .sour: return .citrus
        case .sweet: return .syrups
        case .dairy: return .dairyEgg
        case .lengthener: return .mixers
        case .accent:
            return unit == .dash ? .bitters : .herbsFruit
        case .other: return .seasoning
        }
    }

    // MARK: - Lookups

    func usageCount(for id: String) -> Int { usage[id] ?? 0 }

    func search(_ query: String, category: IngredientCategory? = nil) -> [IngredientIndex.Match] {
        index.search(query, category: category, popularity: usageCount(for:))
    }

    func didYouMean(_ query: String) -> [CatalogIngredient] {
        index.didYouMean(query, popularity: usageCount(for:))
    }

    func category(for name: String) -> IngredientCategory? {
        if let placeholder = DrinkTemplates.placeholderCategory(for: name) { return placeholder }
        return index.resolve(name)?.category
    }

    var recents: [CatalogIngredient] { recentIDs.compactMap(index.entry(id:)) }

    /// The pour a new line of `entry` starts at: the catalog's own default,
    /// else what the deck uses most, else the category's.
    func defaults(for entry: CatalogIngredient) -> IngredientDefault {
        entry.explicitDefault ?? deckDefaults[entry.id] ?? entry.category.fallbackDefault
    }

    // MARK: - Changes

    /// Adds a user ingredient, or returns the existing one if the name is
    /// already known.
    @discardableResult
    func addCustom(name: String, category: IngredientCategory) -> CatalogIngredient {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = index.resolve(trimmed), !houseEntries.contains(existing) {
            return existing
        }
        let entry = CatalogIngredient(id: CatalogIngredient.customID(for: trimmed), name: trimmed, category: category)
        customIngredients.removeAll { $0.id == entry.id }
        customIngredients.append(entry)
        houseEntries.removeAll { $0.id == entry.id }
        rebuild()
        persist()
        return entry
    }

    func noteUsed(_ entry: CatalogIngredient) {
        recentIDs.removeAll { $0 == entry.id }
        recentIDs.insert(entry.id, at: 0)
        recentIDs = Array(recentIDs.prefix(Self.recentLimit))
        persist()
    }

    private func rebuild() {
        index = IngredientIndex(entries: bundled + customIngredients + houseEntries)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        customIngredients = saved.customIngredients
        recentIDs = saved.recentIDs
    }

    private func persist() {
        let saved = Saved(customIngredients: customIngredients, recentIDs: recentIDs)
        guard let data = try? JSONEncoder().encode(saved) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
