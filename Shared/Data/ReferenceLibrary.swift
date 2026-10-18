import Foundation

/// A recipe from the bundled reference set — Bar Assistant's open recipe
/// data (MIT), converted to the deck's schema by
/// `scripts/import-reference.js`. Reference drinks never join the deck; the
/// builder only uses them for pairing ideas, ratio checks, riffs, and close
/// matches.
struct ReferenceDrink: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let family: DrinkFamily
    let glass: GlassType
    let ice: IceType
    let method: DrinkMethod
    let ingredients: [Ingredient]
    let garnish: String
    /// Bar Assistant's own tags: taste ("Bitter", "Citrusy"), style
    /// ("Negroni", "Sour"), and "IBA Cocktail".
    let tags: [String]
    let abv: Double?
    /// The drink this one riffs on, by name, when the source records it.
    let parent: String?
    /// Where the recipe was originally published.
    let source: String?

    /// The same spec as a plain `Drink`, for code that compares drinks.
    var asDrink: Drink {
        Drink(
            id: id,
            name: name,
            family: family,
            glass: glass,
            ice: ice,
            method: method,
            difficulty: 2,
            tags: [.modern],
            ingredients: ingredients,
            garnish: garnish.isEmpty ? "None" : garnish,
            notes: ""
        )
    }

    var ingredientSummary: String { ingredients.map(\.name).joined(separator: ", ") }
}

/// The partners recipes most often use with one ingredient.
struct IngredientPairings: Codable, Hashable {
    struct Partner: Codable, Hashable {
        let name: String
        /// Recipes that use both.
        let together: Int
        /// How often the partner shows up alongside, weighted by how much
        /// more than chance. Comparable across ingredients.
        let score: Double
    }

    /// Recipes that use the ingredient at all.
    let recipes: Int
    let partners: [Partner]
}

/// What share of a family's measured pour each flavor role typically takes.
struct FamilyProfile: Codable, Hashable {
    struct Range: Codable, Hashable {
        /// 25th percentile, median, and 75th percentile, as fractions of the pour.
        let low: Double
        let median: Double
        let high: Double
    }

    /// How many drinks the profile was computed from.
    let drinks: Int
    /// Keyed by `FlavorRole.rawValue`.
    let roles: [String: Range]

    func range(for role: FlavorRole) -> Range? { roles[role.rawValue] }
}

/// The reference recipes plus the pairing and family data precomputed from
/// them (and the deck). Loaded once from the bundle; tests build their own.
struct ReferenceLibrary {
    let drinks: [ReferenceDrink]
    let pairings: [String: IngredientPairings]
    let profiles: [DrinkFamily: FamilyProfile]
    /// Each reference drink's ingredient shares, by id, worked out once so
    /// similarity searches don't redo it for every comparison.
    let ingredientProfiles: [String: [String: Double]]

    init(
        drinks: [ReferenceDrink],
        pairings: [String: IngredientPairings],
        profiles: [DrinkFamily: FamilyProfile],
        index: IngredientIndex = .bundled
    ) {
        self.drinks = drinks
        self.pairings = pairings
        self.profiles = profiles
        ingredientProfiles = Dictionary(
            drinks.map { ($0.id, InventionHelpers.profile(of: $0.ingredients, index: index)) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func ingredientProfile(of drink: ReferenceDrink) -> [String: Double] {
        ingredientProfiles[drink.id] ?? InventionHelpers.profile(of: drink.ingredients)
    }

    static let empty = ReferenceLibrary(drinks: [], pairings: [:], profiles: [:])

    static let bundled: ReferenceLibrary = (try? load()) ?? .empty

    static func load(bundle: Bundle = .main) throws -> ReferenceLibrary {
        func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
            guard let url = bundle.url(forResource: name, withExtension: "json") else {
                throw DrinkLibraryError.resourceNotFound
            }
            do {
                return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
            } catch {
                throw DrinkLibraryError.decodingFailed(error)
            }
        }
        let profilesByName = try decode("family_profiles", as: [String: FamilyProfile].self)
        var profiles: [DrinkFamily: FamilyProfile] = [:]
        for (key, profile) in profilesByName {
            if let family = DrinkFamily(rawValue: key) { profiles[family] = profile }
        }
        return ReferenceLibrary(
            drinks: try decode("reference_drinks", as: [ReferenceDrink].self),
            pairings: try decode("pairings", as: [String: IngredientPairings].self),
            profiles: profiles
        )
    }
}
