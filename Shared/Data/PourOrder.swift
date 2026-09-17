import Foundation

/// Where an ingredient falls in the order a bartender actually pours a drink.
/// Cheapest first: if a pour goes wrong partway through, you've wasted lime
/// juice rather than tequila. Muddled things go in before anything liquid,
/// and anything you top or splash with goes in last, after the shake/stir.
enum PourStage: Int, Comparable, CaseIterable {
    /// A glass rinse (e.g. absinthe for a Sazerac) — done to the glass
    /// before anything is poured, so it's shown with the glass, not the pour.
    case glass
    /// Muddled fruit/herbs, sugar, salt — whatever gets pressed or dissolved
    /// in the bottom of the glass or tin first.
    case prep
    /// Bitters and other dashes.
    case accent
    /// Juices, syrups, cream, egg white, brines, coffee.
    case mixer
    /// Liqueurs, vermouths, amari, aperitifs — the supporting bottles.
    case modifier
    /// The base spirit, poured last so a mistake earlier doesn't waste it.
    case base
    /// Tops, splashes, and floats — added after the shake/stir, in the glass.
    case finish

    static func < (lhs: PourStage, rhs: PourStage) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Sorts a drink's ingredients into pour order. Pure name/unit matching with
/// no SwiftUI dependency, so it's unit-tested against every ingredient in the
/// deck (`PourOrderTests`) and ports straight to a web build.
enum PourOrder {
    /// The stage for one ingredient. Unrecognized names fall back to
    /// `.modifier`; `PourOrderTests` checks that nothing in the deck relies
    /// on that fallback, so a new drink with an unknown ingredient fails a
    /// test instead of silently landing in a strange spot.
    static func stage(name: String, unit: IngredientUnit) -> PourStage {
        classify(name: name, unit: unit) ?? .modifier
    }

    /// Same as `stage`, but `nil` for a name no rule recognizes.
    static func classify(name: String, unit: IngredientUnit) -> PourStage? {
        let lower = name.lowercased()

        // The unit says more about when something goes in than its name
        // does (Angostura is a dash in most drinks but the base of a
        // Trinidad Sour), so it's checked before any name rule.
        switch unit {
        case .rinse: return .glass
        case .muddled, .pinch, .barspoon: return .prep
        case .dash: return .accent
        case .topWith, .splash: return .finish
        case .oz, .optional: break
        }

        if let override = overrides[lower] { return override }

        let words = Set(lower.split(whereSeparator: { !$0.isLetter && $0 != "'" }).map(String.init))

        if finishWords.contains(where: lower.contains) { return .finish }
        if modifierWords.contains(where: lower.contains) { return .modifier }
        if !words.isDisjoint(with: baseWords) || basePhrases.contains(where: lower.contains) { return .base }
        if mixerWords.contains(where: lower.contains) { return .mixer }
        return nil
    }

    /// Ingredients sorted into pour order. Ties keep their spec order, so
    /// e.g. a Long Island's five spirits stay in the order the recipe lists
    /// them. Layered drinks are returned unchanged — their spec order is
    /// density order, and pouring out of it breaks the layers.
    ///
    /// In a built drink, cream is floated on top last (White Russian, Irish
    /// coffee) rather than poured with the other mixers.
    static func ordered(
        _ ingredients: [RecipeScaler.ScaledIngredient],
        method: DrinkMethod
    ) -> [(stage: PourStage, ingredient: RecipeScaler.ScaledIngredient)] {
        let staged = ingredients.map { ingredient -> (stage: PourStage, ingredient: RecipeScaler.ScaledIngredient) in
            var stage = stage(name: ingredient.name, unit: ingredient.unit)
            if method == .build, ingredient.name.lowercased().contains("heavy cream") {
                stage = .finish
            }
            return (stage, ingredient)
        }
        guard method != .layer else { return staged }
        return staged.enumerated()
            .sorted { lhs, rhs in
                lhs.element.stage == rhs.element.stage
                    ? lhs.offset < rhs.offset
                    : lhs.element.stage < rhs.element.stage
            }
            .map(\.element)
    }

    // MARK: - Word lists

    /// Exact (lowercased) names the keyword rules would get wrong.
    private static let overrides: [String: PourStage] = [
        "sloe gin": .modifier,
        "peach brandy": .modifier,
        "southern comfort": .modifier,
        "angostura bitters": .base,   // an oz pour is the base (Trinidad Sour); dashes are caught by unit first
        "absinthe": .modifier,
        "coconut rum": .modifier,
    ]

    private static let finishWords = [
        "champagne", "prosecco", "sparkling", "soda", "tonic", "ginger beer", "ginger ale",
        "cola", "lager", "stout", "cider", "energy drink",
    ]

    private static let modifierWords = [
        "liqueur", "schnapps", "vermouth", "amaro", "aperol", "campari", "cointreau",
        "triple sec", "curaçao", "crème de", "chartreuse", "bénédictine", "drambuie",
        "frangelico", "galliano", "midori", "sambuca", "jägermeister", "amaretto",
        "st-germain", "lillet", "sherry", "pimm's", "heering", "irish cream", "cynar",
    ]

    /// Matched as whole words, so "gin" doesn't match "ginger".
    private static let baseWords: Set<String> = [
        "vodka", "gin", "rum", "rhum", "tequila", "mezcal", "whiskey", "bourbon", "rye",
        "scotch", "brandy", "cognac", "calvados", "applejack", "pisco", "cachaça",
    ]

    private static let basePhrases = [
        "jack daniel's", "jim beam", "johnnie walker", "crown royal",
    ]

    private static let mixerWords = [
        "juice", "syrup", "cream", "egg white", "purée", "brine", "espresso", "coffee",
        "sour mix", "cordial", "grenadine", "orgeat", "falernum", "lemonade", "iced tea",
        "milk", "sugar",
    ]
}
