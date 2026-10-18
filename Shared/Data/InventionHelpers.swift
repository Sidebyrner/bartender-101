import Foundation

/// Ideas for a drink in progress, drawn from the reference recipes: what's
/// often paired with what's already in it, how its proportions compare with
/// its family, documented riffs on a classic, and existing drinks it's close
/// to. Pure functions, like `DrinkBalance`.
///
/// Everything here reflects what recipes use, not what tastes good — the UI
/// says "often paired with", never "goes great with".
enum InventionHelpers {
    // MARK: - Pairings

    struct Suggestion: Identifiable, Hashable {
        var id: String { name }
        /// A catalog ingredient name.
        let name: String
        let score: Double
        /// The ingredients already in the drink it's most often paired with,
        /// best first, with how many recipes use both.
        let pairedWith: [(name: String, together: Int)]

        static func == (lhs: Suggestion, rhs: Suggestion) -> Bool { lhs.name == rhs.name && lhs.score == rhs.score }
        func hash(into hasher: inout Hasher) { hasher.combine(name) }

        /// e.g. "With Gin (46) and Lemon juice (31)".
        var reason: String {
            let parts = pairedWith.prefix(2).map { "\($0.name) (\($0.together))" }
            return "With " + parts.joined(separator: " and ")
        }
    }

    /// The catalog name an ingredient line refers to, or nil for template
    /// stand-ins and names the catalog doesn't know.
    static func canonicalName(_ name: String, index: IngredientIndex = .bundled) -> String? {
        guard DrinkTemplates.placeholderCategory(for: name) == nil else { return nil }
        return index.resolve(name)?.name
    }

    /// Ingredients often paired with everything already in the drink, best
    /// first. Something paired with several of its ingredients ranks above
    /// something paired strongly with just one.
    static func pairings(
        for ingredients: [Ingredient],
        limit: Int = 8,
        reference: ReferenceLibrary = .bundled,
        index: IngredientIndex = .bundled
    ) -> [Suggestion] {
        let present = Set(ingredients.compactMap { canonicalName($0.name, index: index) })
        guard !present.isEmpty else { return [] }

        var scores: [String: Double] = [:]
        var reasons: [String: [(name: String, together: Int)]] = [:]
        for name in present.sorted() {
            for partner in reference.pairings[name]?.partners ?? [] where !present.contains(partner.name) {
                scores[partner.name, default: 0] += partner.score
                reasons[partner.name, default: []].append((name, partner.together))
            }
        }
        return scores
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(limit)
            .map { name, score in
                Suggestion(name: name, score: score, pairedWith: (reasons[name] ?? []).sorted { $0.together > $1.together })
            }
    }

    // MARK: - Ratio check

    struct RatioCheck: Equatable {
        struct Note: Equatable, Hashable {
            enum Direction { case high, low }
            let role: FlavorRole
            /// This drink's share of the measured pour.
            let share: Double
            /// The family's middle half (25th–75th percentile).
            let typical: ClosedRange<Double>
            let direction: Direction
        }

        let family: DrinkFamily
        /// Drinks the family profile was computed from.
        let drinksCompared: Int
        /// Roles well outside the family's middle half.
        let notes: [Note]
    }

    /// Roles a profile covers — the ones that carry real volume.
    static let profiledRoles: [FlavorRole] = [.spirit, .modifier, .sour, .sweet, .dairy, .lengthener]

    /// How far outside the middle half a share has to be before it's
    /// worth mentioning, so a drink that's a hair off doesn't get a note.
    static let ratioMargin = 0.05

    /// Compares a drink's proportions with what its family usually does.
    /// Nil until two kinds of thing are measured (a lone spirit is always
    /// "off"), for Misc (a grab bag with no typical shape), and when the
    /// family has too few drinks to say what's typical.
    static func ratioCheck(
        summary: DrinkBalance.Summary,
        family: DrinkFamily,
        reference: ReferenceLibrary = .bundled
    ) -> RatioCheck? {
        guard family != .misc,
              summary.totalOz > 0,
              summary.ozByRole.filter({ $0.value > 0 }).count >= 2,
              let profile = reference.profiles[family], profile.drinks >= 8 else { return nil }
        var notes: [RatioCheck.Note] = []
        for role in profiledRoles {
            guard let range = profile.range(for: role) else { continue }
            let share = summary.oz(role) / summary.totalOz
            let typical = range.low...range.high
            if share > range.high + ratioMargin {
                notes.append(.init(role: role, share: share, typical: typical, direction: .high))
            } else if share < range.low - ratioMargin {
                notes.append(.init(role: role, share: share, typical: typical, direction: .low))
            }
        }
        return RatioCheck(family: family, drinksCompared: profile.drinks, notes: notes)
    }

    // MARK: - Similarity

    /// Each ingredient's share of the drink. Unmeasured lines (dashes,
    /// muddled mint) count a little, so they still tell drinks apart.
    static func profile(of ingredients: [Ingredient], index: IngredientIndex = .bundled) -> [String: Double] {
        var weights: [String: Double] = [:]
        for ingredient in ingredients {
            guard let name = canonicalName(ingredient.name, index: index) else { continue }
            weights[name, default: 0] += ingredient.amountOz.map { max($0, 0) } ?? 0.25
        }
        let total = weights.values.reduce(0, +)
        guard total > 0 else { return [:] }
        return weights.mapValues { $0 / total }
    }

    /// Weighted Jaccard similarity of two ingredient profiles, 0...1.
    static func similarity(_ a: [String: Double], _ b: [String: Double]) -> Double {
        var shared = 0.0, union = 0.0
        for key in Set(a.keys).union(b.keys) {
            let x = a[key] ?? 0, y = b[key] ?? 0
            shared += min(x, y)
            union += max(x, y)
        }
        return union > 0 ? shared / union : 0
    }

    struct Match: Identifiable, Hashable {
        var id: String { drink.id }
        let drink: Drink
        /// Set when the match is a reference recipe rather than a deck drink.
        let reference: ReferenceDrink?
        let similarity: Double

        var percent: Int { Int((similarity * 100).rounded()) }
    }

    /// Existing drinks — deck first, then reference — closest to the spec
    /// in progress. Needs at least two named ingredients to say anything.
    static func closeMatches(
        for ingredients: [Ingredient],
        deck: [Drink],
        excludingID: String? = nil,
        limit: Int = 3,
        minimum: Double = 0.45,
        reference: ReferenceLibrary = .bundled,
        index: IngredientIndex = .bundled
    ) -> [Match] {
        let mine = profile(of: ingredients, index: index)
        guard mine.count >= 2 else { return [] }
        var matches: [Match] = []
        for drink in deck where drink.id != excludingID {
            let score = similarity(mine, profile(of: drink.ingredients, index: index))
            if score >= minimum { matches.append(Match(drink: drink, reference: nil, similarity: score)) }
        }
        for ref in reference.drinks {
            let score = similarity(mine, reference.ingredientProfile(of: ref))
            if score >= minimum { matches.append(Match(drink: ref.asDrink, reference: ref, similarity: score)) }
        }
        return Array(matches
            .sorted { $0.similarity != $1.similarity ? $0.similarity > $1.similarity : $0.drink.name < $1.drink.name }
            .prefix(limit))
    }

    // MARK: - Riffs

    /// Documented riffs on `drink`: reference recipes that name it as their
    /// parent or carry it as a style tag ("Negroni"), then same-family
    /// recipes that share most of its spec.
    static func riffs(
        of drink: Drink,
        limit: Int = 12,
        reference: ReferenceLibrary = .bundled,
        index: IngredientIndex = .bundled
    ) -> [ReferenceDrink] {
        let key = IngredientIndex.normalize(drink.name)
        guard !key.isEmpty else { return [] }
        let candidates = reference.drinks.filter { IngredientIndex.normalize($0.name) != key }

        let named = candidates.filter { ref in
            ref.parent.map(IngredientIndex.normalize) == key
                || ref.tags.contains { IngredientIndex.normalize($0) == key }
        }
        let namedIDs = Set(named.map(\.id))

        let base = profile(of: drink.ingredients, index: index)
        let similar = candidates
            .filter { $0.family == drink.family && !namedIDs.contains($0.id) }
            .map { ($0, similarity(base, reference.ingredientProfile(of: $0))) }
            .filter { $0.1 >= 0.5 }
            .sorted { $0.1 > $1.1 }
            .map(\.0)

        return Array((named.sorted { $0.name < $1.name } + similar).prefix(limit))
    }
}

extension DrinkTemplates {
    /// A copy of a reference recipe to change. It isn't in the deck, so
    /// there's no `basedOnDrinkID` — the notes say where it came from.
    static func riff(on reference: ReferenceDrink) -> CustomDrink {
        CustomDrink(
            name: "",
            family: reference.family,
            glass: reference.glass,
            ice: reference.ice,
            method: reference.method,
            ingredients: reference.ingredients,
            garnish: reference.garnish,
            notes: "Riff on the \(reference.name)."
        )
    }
}
