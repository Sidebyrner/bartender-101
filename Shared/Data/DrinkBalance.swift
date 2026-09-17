import Foundation

/// What an ingredient does to a drink's balance — the builder's meter groups
/// pours by this.
enum FlavorRole: String, CaseIterable {
    /// The base spirit.
    case spirit
    /// Liqueurs, vermouths, amari, aperitifs.
    case modifier
    /// Citrus and other acids.
    case sour
    /// Syrups, sugar, honey, purées.
    case sweet
    /// Cream, egg, milk.
    case dairy
    /// Sodas, juices, wine, beer, coffee — whatever makes the drink longer.
    case lengthener
    /// Dashes, rinses, muddled herbs, seasoning — flavor, but no real volume.
    case accent
    /// A name no rule recognizes.
    case other

    var displayName: String {
        switch self {
        case .spirit: return "Spirit"
        case .modifier: return "Liqueur"
        case .sour: return "Sour"
        case .sweet: return "Sweet"
        case .dairy: return "Cream & egg"
        case .lengthener: return "Long"
        case .accent: return "Accent"
        case .other: return "Other"
        }
    }
}

extension DrinkFamily {
    /// Rough total-oz range a drink in this family falls in. Copied from
    /// `OZ_BANDS` in `scripts/validate-drinks.js` — keep the two in sync.
    var ozBand: ClosedRange<Double> {
        switch self {
        case .highball, .mule, .tiki: return 2...8
        case .sour: return 1.5...5
        case .oldFashioned: return 1.5...3.5
        case .martini, .manhattan: return 1.5...4.5
        case .spritz: return 2...6.5
        case .muddled: return 1.5...8
        case .cream: return 2...4
        case .shot: return 1...3.5
        case .misc: return 1.5...12
        }
    }
}

/// The live balance read-out for a spec in progress: how much of each role is
/// in the glass, and a few bartending rules of thumb it breaks. Pure
/// functions, built on `PourOrder`'s ingredient word lists so the two never
/// disagree about what counts as a spirit or a liqueur.
enum DrinkBalance {
    struct Summary: Equatable {
        /// Measured oz per role. Roles with nothing measured are absent.
        let ozByRole: [FlavorRole: Double]
        /// Every measured amount, tops included — the same total the deck
        /// validator checks against the family's oz band.
        let totalOz: Double
        let warnings: [String]

        func oz(_ role: FlavorRole) -> Double { ozByRole[role] ?? 0 }
    }

    static func role(name: String, unit: IngredientUnit) -> FlavorRole {
        let lower = name.lowercased()
        switch unit {
        case .dash, .rinse, .barspoon, .pinch, .muddled: return .accent
        case .topWith, .splash:
            if isSour(lower) { return .sour }
            if sweetWords.contains(where: lower.contains) { return .sweet }
            return .lengthener
        case .oz, .optional: break
        }
        if lower.contains("spirit") { return .spirit }

        switch PourOrder.classify(name: name, unit: .oz) {
        case .base: return .spirit
        case .modifier: return .modifier
        case .finish: return .lengthener
        case .mixer:
            if isSour(lower) { return .sour }
            if dairyWords.contains(where: lower.contains) { return .dairy }
            if sweetWords.contains(where: lower.contains) { return .sweet }
            return .lengthener
        case .glass, .prep, .accent, nil:
            if isSour(lower) { return .sour }
            if sweetWords.contains(where: lower.contains) { return .sweet }
            return .other
        }
    }

    static func summary(for ingredients: [Ingredient], family: DrinkFamily, method: DrinkMethod) -> Summary {
        var ozByRole: [FlavorRole: Double] = [:]
        var present = Set<FlavorRole>()
        var totalOz = 0.0

        for ingredient in ingredients where !ingredient.name.trimmingCharacters(in: .whitespaces).isEmpty {
            let role = role(name: ingredient.name, unit: ingredient.unit)
            present.insert(role)
            if let oz = ingredient.amountOz, oz > 0 {
                totalOz += oz
                ozByRole[role, default: 0] += oz
            }
        }

        var warnings: [String] = []
        guard !present.isEmpty else {
            return Summary(ozByRole: [:], totalOz: 0, warnings: [])
        }

        let band = family.ozBand
        if totalOz < band.lowerBound {
            warnings.append("\(Measure.ozFraction(totalOz)) oz is short for a \(family.displayName.lowercased()) (usually \(Measure.ozFraction(band.lowerBound))–\(Measure.ozFraction(band.upperBound)) oz)")
        } else if totalOz > band.upperBound {
            warnings.append("\(Measure.ozFraction(totalOz)) oz is long for a \(family.displayName.lowercased()) (usually \(Measure.ozFraction(band.lowerBound))–\(Measure.ozFraction(band.upperBound)) oz)")
        }
        if method == .stir && (present.contains(.sour) || present.contains(.dairy)) {
            warnings.append("Citrus, cream, and egg get shaken — stirring won't mix them")
        }
        // A juice can stand in for citrus (Blood and Sand, Mary Pickford).
        if family == .sour && !present.contains(.sour) && !present.contains(.lengthener) {
            warnings.append("A sour needs citrus")
        }
        // Spritzes and misc drinks can be all wine, beer, or no alcohol at all.
        if family != .spritz && family != .misc && !present.contains(.spirit) && !present.contains(.modifier) {
            warnings.append("No spirit or liqueur yet")
        }
        if present.contains(.sour) && present.isDisjoint(with: [.sweet, .modifier, .lengthener, .dairy]) {
            warnings.append("Citrus with nothing sweet will drink very tart")
        }

        return Summary(ozByRole: ozByRole, totalOz: totalOz, warnings: warnings)
    }

    // MARK: - Word lists

    private static let sourWords = ["lemon", "lime", "citrus", "sour mix", "yuzu", "verjus", "acid"]

    /// Citrus-named things that are really sweet or long, not sour.
    private static let notSourWords = ["lemonade", "cordial", "soda"]

    private static func isSour(_ lower: String) -> Bool {
        sourWords.contains(where: lower.contains) && !notSourWords.contains(where: lower.contains)
    }

    private static let dairyWords = ["cream", "egg", "milk"]

    private static let sweetWords = [
        "syrup", "sugar", "honey", "agave", "grenadine", "orgeat", "falernum", "purée",
        "cordial", "sweetener",
    ]
}
