import Foundation

/// The family a drink belongs to. Drives grouping in Browse, distractor
/// selection in the speed drill (wrong answers come from the same family so
/// the drill trains real discrimination), and the oz sanity check that also
/// runs in `scripts/validate-drinks.js` — keep the raw values identical to
/// the strings used there and in `Resources/drinks.json`.
enum DrinkFamily: String, Codable, CaseIterable, Identifiable {
    case highball
    case mule
    case sour
    case oldFashioned
    case martini
    case manhattan
    case spritz
    case tiki
    case muddled
    case cream
    case shot
    case misc

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .highball: return "Highball"
        case .mule: return "Mule"
        case .sour: return "Sour"
        case .oldFashioned: return "Old Fashioned"
        case .martini: return "Martini"
        case .manhattan: return "Manhattan"
        case .spritz: return "Spritz & Bubbles"
        case .tiki: return "Tiki"
        case .muddled: return "Muddled & Long"
        case .cream: return "Cream & Dessert"
        case .shot: return "Shot"
        case .misc: return "Misc"
        }
    }
}

enum GlassType: String, Codable, CaseIterable {
    case highball, collins, copperMug, rocks, coupe, martini
    case wine, flute, hurricane, julepCup, shot, irishCoffeeMug

    var displayName: String {
        switch self {
        case .copperMug: return "Copper Mug"
        case .julepCup: return "Julep Cup"
        case .irishCoffeeMug: return "Irish Coffee Mug"
        default: return rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }
}

enum IceType: String, Codable, CaseIterable {
    case cubed, largeCube, crushed, none

    var displayName: String {
        switch self {
        case .cubed: return "Cubed"
        case .largeCube: return "Large cube"
        case .crushed: return "Crushed"
        case .none: return "None"
        }
    }
}

enum DrinkMethod: String, Codable, CaseIterable {
    case build, shake, stir, muddle, blend, layer

    var displayName: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

enum DrinkTag: String, Codable, CaseIterable, Identifiable {
    case well, classic, shot, tiki, modern

    var id: String { rawValue }

    var displayName: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

/// One drink's full professional spec — the content of a single index card.
/// Decoded straight from `Resources/drinks.json`, which is the same schema
/// a future web build will read, so this stays a plain value type with no
/// storage or UI coupling.
struct Drink: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let family: DrinkFamily
    let glass: GlassType
    let ice: IceType
    let method: DrinkMethod
    /// 1 (easy) to 3 (hard) — used to weight the speed drill's card order.
    let difficulty: Int
    let tags: [DrinkTag]
    let ingredients: [Ingredient]
    let garnish: String
    let notes: String

    static func == (lhs: Drink, rhs: Drink) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// A comma-joined ingredient list, e.g. "Gin, Campari, Sweet vermouth" —
    /// used as the answer text in the speed drill and reverse quiz, where a
    /// full spec would be too much to read against a clock.
    var ingredientSummary: String {
        ingredients.map(\.name).joined(separator: ", ")
    }
}
