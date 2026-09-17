import Foundation

/// Plain-language method lines for a drink, derived from its method, glass,
/// and ice — e.g. "Shake hard with ice" then "Strain up into a chilled
/// coupe". Nothing extra is stored in `drinks.json`; the three fields every
/// drink already has are enough. Pure, so it's unit-tested
/// (`BuildStepsTests`) and ports to a web build as-is.
enum BuildSteps {
    static func methodLines(for drink: Drink) -> [String] {
        methodLines(method: drink.method, glass: drink.glass, ice: drink.ice)
    }

    static func methodLines(method: DrinkMethod, glass: GlassType, ice: IceType) -> [String] {
        switch method {
        case .shake:
            return ["Shake hard with ice", strainLine(glass: glass, ice: ice)]
        case .stir:
            return ["Stir with ice, about 20 seconds", strainLine(glass: glass, ice: ice)]
        case .build:
            return ["Build in the glass, in pour order"]
        case .muddle:
            let iceStep = ice == .none ? "stir" : "add \(icePhrase(ice)), swizzle"
            return ["Muddle in the glass, pour the rest, \(iceStep)"]
        case .blend:
            return ["Blend with a scoop of ice until smooth", "Pour into \(withArticle(servingName(glass)))"]
        case .layer:
            return ["Layer slowly over the back of a barspoon, in pour order"]
        }
    }

    private static func strainLine(glass: GlassType, ice: IceType) -> String {
        if glass == .shot { return "Strain into a shot glass" }
        if ice == .none { return "Strain up into a chilled \(servingName(glass))" }
        return "Strain into \(withArticle(servingName(glass))) over \(icePhrase(ice))"
    }

    private static func icePhrase(_ ice: IceType) -> String {
        switch ice {
        case .cubed: return "fresh ice"
        case .largeCube: return "a fresh large cube"
        case .crushed: return "crushed ice"
        case .none: return "no ice"
        }
    }

    /// How you'd say the glass out loud behind the bar: "rocks glass",
    /// "coupe", "copper mug".
    static func servingName(_ glass: GlassType) -> String {
        switch glass {
        case .highball: return "highball glass"
        case .collins: return "Collins glass"
        case .copperMug: return "copper mug"
        case .rocks: return "rocks glass"
        case .coupe: return "coupe"
        case .martini: return "martini glass"
        case .wine: return "wine glass"
        case .flute: return "flute"
        case .hurricane: return "hurricane glass"
        case .julepCup: return "julep cup"
        case .shot: return "shot glass"
        case .irishCoffeeMug: return "Irish coffee mug"
        case .tikiMug: return "tiki mug"
        case .punchBowl: return "punch bowl"
        }
    }

    private static func withArticle(_ noun: String) -> String {
        let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
        guard let first = noun.lowercased().first else { return noun }
        return (vowels.contains(first) ? "an " : "a ") + noun
    }
}
