import Foundation

/// Name lookup and ranked search over a set of catalog ingredients. A pure
/// value type — `IngredientCatalog` rebuilds one whenever its ingredients
/// change, and tests build their own — so the matching rules are unit-tested
/// and port to a web build like `FuzzyMatch`.
struct IngredientIndex {
    let entries: [CatalogIngredient]
    private var byKey: [String: CatalogIngredient] = [:]
    private var byID: [String: CatalogIngredient] = [:]

    init(entries: [CatalogIngredient]) {
        self.entries = entries
        for entry in entries {
            byID[entry.id] = entry
            for key in [entry.name] + entry.aliases {
                let normalized = Self.normalize(key)
                if byKey[normalized] == nil { byKey[normalized] = entry }
            }
        }
    }

    /// The ingredients bundled in `Resources/ingredients.json`.
    static let bundled: IngredientIndex = IngredientIndex(entries: (try? loadBundled()) ?? [])

    static func loadBundled(bundle: Bundle = .main) throws -> [CatalogIngredient] {
        guard let url = bundle.url(forResource: "ingredients", withExtension: "json") else {
            throw DrinkLibraryError.resourceNotFound
        }
        return try JSONDecoder().decode([CatalogIngredient].self, from: Data(contentsOf: url))
    }

    /// Lowercased, accents folded, punctuation turned into single spaces:
    /// "Crème de Mûre" and "creme-de-mure" both become "creme de mure".
    static func normalize(_ string: String) -> String {
        let folded = string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
        let spaced = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
        return String(spaced).split(separator: " ").joined(separator: " ")
    }

    func entry(id: String) -> CatalogIngredient? { byID[id] }

    /// The ingredient a name exactly refers to, by name or alias (ignoring
    /// case, accents, and punctuation).
    func resolve(_ name: String) -> CatalogIngredient? {
        byKey[Self.normalize(name)]
    }

    struct Match: Hashable {
        let entry: CatalogIngredient
        /// Lower is better. Below 1 means an exact name or alias.
        let score: Double
        /// The alias that matched, when it wasn't the name.
        let matchedAlias: String?

        var isExact: Bool { score < 1 }
    }

    /// Ingredients matching `query`, best first: exact name, then alias,
    /// name prefix, word prefix, run-together prefix ("limejuice"),
    /// substring, and finally typos. Ties go to whatever the deck uses most
    /// (`popularity`), then alphabetical.
    func search(_ query: String, category: IngredientCategory? = nil, popularity: (String) -> Int = { _ in 0 }) -> [Match] {
        let q = Self.normalize(query)
        let pool = entries.filter { category == nil || $0.category == category }
        guard !q.isEmpty else {
            return pool
                .map { Match(entry: $0, score: 10, matchedAlias: nil) }
                .sorted { sortOrder($0, $1, popularity: popularity) }
        }

        var matches: [Match] = []
        for entry in pool {
            var best: (score: Double, alias: String?)?
            for (index, key) in ([entry.name] + entry.aliases).enumerated() {
                guard let score = Self.score(query: q, key: Self.normalize(key)) else { continue }
                // An alias ranks just behind the same kind of match on a name.
                let adjusted = score + (index == 0 ? 0 : 0.5)
                if best == nil || adjusted < best!.score {
                    best = (adjusted, index == 0 ? nil : key)
                }
            }
            if let best {
                matches.append(Match(entry: entry, score: best.score, matchedAlias: best.alias))
            }
        }
        return matches.sorted { sortOrder($0, $1, popularity: popularity) }
    }

    /// The closest few names to something that didn't match exactly — for
    /// "Did you mean…?" before a new ingredient is added.
    func didYouMean(_ query: String, limit: Int = 3, popularity: (String) -> Int = { _ in 0 }) -> [CatalogIngredient] {
        let q = Self.normalize(query)
        guard q.count >= 3, resolve(q) == nil else { return [] }
        let tolerance = max(2, q.count / 3)
        var scored: [(entry: CatalogIngredient, distance: Int)] = []
        for entry in entries {
            let distance = ([entry.name] + entry.aliases)
                .map { Self.normalize($0) }
                .map { key -> Int in
                    let whole = FuzzyMatch.distance(q, key)
                    // Also compare against the start of a longer name, so
                    // "angostra" is close to "angostura bitters".
                    let prefix = key.count > q.count ? FuzzyMatch.distance(q, String(key.prefix(q.count))) : whole
                    return min(whole, prefix)
                }
                .min() ?? .max
            if distance <= tolerance { scored.append((entry, distance)) }
        }
        return scored
            .sorted { $0.distance != $1.distance ? $0.distance < $1.distance : popularity($0.entry.id) > popularity($1.entry.id) }
            .prefix(limit)
            .map(\.entry)
    }

    private func sortOrder(_ lhs: Match, _ rhs: Match, popularity: (String) -> Int) -> Bool {
        if lhs.score != rhs.score { return lhs.score < rhs.score }
        let lp = popularity(lhs.entry.id), rp = popularity(rhs.entry.id)
        if lp != rp { return lp > rp }
        return lhs.entry.name.localizedCaseInsensitiveCompare(rhs.entry.name) == .orderedAscending
    }

    /// How well a normalized query matches one normalized name or alias, or
    /// nil for no match.
    static func score(query q: String, key: String) -> Double? {
        if key == q { return 0 }
        if key.hasPrefix(q) { return 1 }
        let words = key.split(separator: " ")
        if words.contains(where: { $0.hasPrefix(q) }) { return 2 }
        let compactKey = key.replacingOccurrences(of: " ", with: "")
        let compactQuery = q.replacingOccurrences(of: " ", with: "")
        if compactKey.hasPrefix(compactQuery) { return 2.25 }
        if key.contains(q) || compactKey.contains(compactQuery) { return 3 }

        // Typos. Short queries are too ambiguous to guess at.
        guard compactQuery.count >= 4 else { return nil }
        let tolerance = max(1, key.count / 5)
        let whole = FuzzyMatch.distance(q, key)
        if whole <= tolerance { return 4 + Double(whole) / 10 }
        // A partly typed name with a typo in it: "angostr" → "angostura bitters".
        if key.count > q.count {
            let prefix = FuzzyMatch.distance(q, String(key.prefix(q.count)))
            if prefix <= max(1, q.count / 5) { return 5 + Double(prefix) / 10 }
        }
        return nil
    }
}
