import Foundation

enum DrinkLibraryError: Error {
    case resourceNotFound
    case decodingFailed(Error)
}

/// Loads and indexes the drink deck from `Resources/drinks.json`, merged with
/// house drinks from the Build tab. Owns no mutable study state — that's
/// `ReviewStore`'s job — this is read-only content plus lookup/search/filter
/// helpers the feature views share.
@MainActor
final class DrinkLibrary: ObservableObject {
    /// The deck plus house drinks that are on the menu — everything Search,
    /// Study, and Stats treat as "the deck".
    @Published private(set) var drinks: [Drink] = []
    @Published private(set) var loadError: String?

    private var deck: [Drink] = []
    private var customDrinks: [CustomDrink] = []
    /// Every drink by id, including house drinks still in testing, so a
    /// shift-log row for a test pour still opens its recipe.
    private var byID: [String: Drink] = [:]
    private var byFamily: [DrinkFamily: [Drink]] = [:]

    init(deck: [Drink]? = nil) {
        if let deck {
            self.deck = deck
            rebuildIndex()
        } else {
            load()
        }
    }

    private func load() {
        do {
            deck = try Self.loadDrinks()
        } catch {
            loadError = "Couldn't load the drink deck: \(error)"
            deck = []
        }
        rebuildIndex()
    }

    /// Replaces the house drinks merged into the deck. Called whenever
    /// `CustomDrinkStore` changes.
    func setCustomDrinks(_ all: [CustomDrink]) {
        customDrinks = all
        rebuildIndex()
    }

    private func rebuildIndex() {
        let onMenu = customDrinks.filter { $0.stage == .onMenu }.map { $0.asDrink() }
        drinks = deck + onMenu
        byID = Dictionary(deck.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for custom in customDrinks {
            byID[custom.id] = custom.asDrink()
        }
        byFamily = Dictionary(grouping: drinks, by: \.family)
    }

    /// Whether `name` is already used by a deck drink or another house drink
    /// (case-insensitive), ignoring the house drink with id `excluding`.
    func isNameTaken(_ name: String, excluding id: String? = nil) -> Bool {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return false }
        if deck.contains(where: { $0.name.lowercased() == key }) { return true }
        return customDrinks.contains { $0.id != id && $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == key }
    }

    static func loadDrinks() throws -> [Drink] {
        guard let url = Bundle.main.url(forResource: "drinks", withExtension: "json") else {
            throw DrinkLibraryError.resourceNotFound
        }
        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode([Drink].self, from: data)
        } catch {
            throw DrinkLibraryError.decodingFailed(error)
        }
    }

    func drink(id: String) -> Drink? { byID[id] }

    func drinks(in family: DrinkFamily) -> [Drink] { byFamily[family] ?? [] }

    /// Drinks whose name or ingredient list match `query`, case-insensitive.
    /// Empty query returns the full deck.
    func search(_ query: String) -> [Drink] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return drinks }
        return drinks.filter { drink in
            drink.name.lowercased().contains(q)
                || drink.ingredients.contains { $0.name.lowercased().contains(q) }
        }
    }

    func drinks(matchingTags tags: Set<DrinkTag>) -> [Drink] {
        guard !tags.isEmpty else { return drinks }
        return drinks.filter { !Set($0.tags).isDisjoint(with: tags) }
    }

    /// Picks `count` other drinks to serve as wrong answers for `drink`.
    /// Pulled from the same family first (so a Negroni's distractors are
    /// other stirred aperitifs, not a Piña Colada — the whole point of the
    /// speed drill is training discrimination within a family), then padded
    /// from the rest of the deck if that family is too small.
    func distractors(for drink: Drink, count: Int) -> [Drink] {
        var pool = drinks(in: drink.family).filter { $0.id != drink.id }
        pool.shuffle()
        if pool.count < count {
            var fallback = drinks.filter { $0.id != drink.id && $0.family != drink.family }
            fallback.shuffle()
            pool.append(contentsOf: fallback)
        }
        return Array(pool.prefix(count))
    }
}
