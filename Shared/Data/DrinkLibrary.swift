import Foundation

enum DrinkLibraryError: Error {
    case resourceNotFound
    case decodingFailed(Error)
}

/// Loads and indexes the drink deck from `Resources/drinks.json`. Owns no
/// mutable study state — that's `ReviewStore`'s job — this is read-only
/// content plus lookup/search/filter helpers the feature views share.
@MainActor
final class DrinkLibrary: ObservableObject {
    @Published private(set) var drinks: [Drink] = []
    @Published private(set) var loadError: String?

    private var byID: [String: Drink] = [:]
    private var byFamily: [DrinkFamily: [Drink]] = [:]

    init() {
        load()
    }

    private func load() {
        do {
            drinks = try Self.loadDrinks()
            byID = Dictionary(uniqueKeysWithValues: drinks.map { ($0.id, $0) })
            byFamily = Dictionary(grouping: drinks, by: \.family)
        } catch {
            loadError = "Couldn't load the drink deck: \(error)"
            drinks = []
        }
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
