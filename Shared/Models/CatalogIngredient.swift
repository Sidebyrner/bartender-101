import Foundation

/// The shelf an ingredient lives on — the picker's category chips, the icon
/// on a builder row, the balance meter's role, and which unit rules apply.
/// Raw values match `category` in `Resources/ingredients.json` and
/// `scripts/validate-drinks.js`.
enum IngredientCategory: String, Codable, CaseIterable, Identifiable {
    case spirits
    case liqueurs
    case vermouthAmari
    case citrus
    case syrups
    case juices
    case mixers
    case wineBeer
    case bitters
    case dairyEgg
    case herbsFruit
    case seasoning

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spirits: return "Spirits"
        case .liqueurs: return "Liqueurs"
        case .vermouthAmari: return "Vermouth & Amari"
        case .citrus: return "Citrus"
        case .syrups: return "Syrups & Sweet"
        case .juices: return "Juices"
        case .mixers: return "Sodas & Mixers"
        case .wineBeer: return "Wine & Beer"
        case .bitters: return "Bitters"
        case .dairyEgg: return "Dairy & Egg"
        case .herbsFruit: return "Herbs & Fruit"
        case .seasoning: return "Seasoning"
        }
    }

    /// Singular, for prompts like "Choose a spirit".
    var choosePrompt: String {
        switch self {
        case .spirits: return "Choose a spirit"
        case .liqueurs: return "Choose a liqueur"
        case .vermouthAmari: return "Choose a vermouth or amaro"
        case .citrus: return "Choose a citrus"
        case .syrups: return "Choose a sweetener"
        case .juices: return "Choose a juice"
        case .mixers: return "Choose a mixer"
        case .wineBeer: return "Choose a wine or beer"
        case .bitters: return "Choose bitters"
        case .dairyEgg: return "Choose dairy or egg"
        case .herbsFruit: return "Choose an herb or fruit"
        case .seasoning: return "Choose a seasoning"
        }
    }

    var systemImage: String {
        switch self {
        case .spirits: return "flame"
        case .liqueurs: return "drop.fill"
        case .vermouthAmari: return "wineglass"
        case .citrus: return "circle.lefthalf.filled"
        case .syrups: return "cube"
        case .juices: return "carrot"
        case .mixers: return "bubbles.and.sparkles"
        case .wineBeer: return "mug"
        case .bitters: return "eyedropper"
        case .dairyEgg: return "oval.portrait"
        case .herbsFruit: return "leaf"
        case .seasoning: return "sparkles"
        }
    }

    /// The pour a new line in this category starts at when neither the
    /// catalog nor the deck says otherwise.
    var fallbackDefault: IngredientDefault {
        switch self {
        case .spirits: return IngredientDefault(unit: .oz, amountOz: 2)
        case .liqueurs: return IngredientDefault(unit: .oz, amountOz: 0.5)
        case .vermouthAmari: return IngredientDefault(unit: .oz, amountOz: 1)
        case .citrus: return IngredientDefault(unit: .oz, amountOz: 0.75)
        case .syrups: return IngredientDefault(unit: .oz, amountOz: 0.5)
        case .juices: return IngredientDefault(unit: .oz, amountOz: 2)
        case .mixers, .wineBeer: return IngredientDefault(unit: .topWith, amountOz: 4)
        case .bitters: return IngredientDefault(unit: .dash, count: 2)
        case .dairyEgg: return IngredientDefault(unit: .oz, amountOz: 1)
        case .herbsFruit: return IngredientDefault(unit: .muddled, count: 4)
        case .seasoning: return IngredientDefault(unit: .pinch)
        }
    }

    /// What this category does to a drink's balance.
    var flavorRole: FlavorRole {
        switch self {
        case .spirits: return .spirit
        case .liqueurs, .vermouthAmari, .bitters: return .modifier
        case .citrus: return .sour
        case .syrups: return .sweet
        case .juices, .mixers, .wineBeer: return .lengthener
        case .dairyEgg: return .dairy
        case .herbsFruit: return .accent
        case .seasoning: return .other
        }
    }
}

/// A starting unit and amount for a new ingredient line.
struct IngredientDefault: Hashable {
    var unit: IngredientUnit
    var amountOz: Double?
    var count: Int?

    init(unit: IngredientUnit, amountOz: Double? = nil, count: Int? = nil) {
        self.unit = unit
        self.amountOz = amountOz
        self.count = count
    }

    /// e.g. "¾ oz", "2 dashes", "Top with".
    func label(unit measurement: MeasurementUnit) -> String {
        if unit.expectsAmount, unit == .oz, let amountOz {
            return Measure.label(oz: amountOz, unit: measurement)
        }
        return ingredient(named: "").countLabel ?? ""
    }

    func ingredient(named name: String) -> Ingredient {
        Ingredient(
            name: name,
            amountOz: unit.expectsAmount ? (amountOz ?? 1) : nil,
            unit: unit,
            dashCount: unit == .dash ? (count ?? 1) : nil,
            approxCount: unit == .muddled ? count : nil,
            spoonCount: unit == .barspoon ? (count ?? 1) : nil
        )
    }
}

/// One ingredient the picker knows about — from `Resources/ingredients.json`,
/// or added by the user from the picker.
struct CatalogIngredient: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: IngredientCategory
    /// Other names it goes by: brands ("Kahlúa"), shorthand ("OJ").
    let aliases: [String]
    let defaultUnit: IngredientUnit?
    let defaultOz: Double?
    let defaultCount: Int?

    init(id: String, name: String, category: IngredientCategory, aliases: [String] = [],
         defaultUnit: IngredientUnit? = nil, defaultOz: Double? = nil, defaultCount: Int? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.aliases = aliases
        self.defaultUnit = defaultUnit
        self.defaultOz = defaultOz
        self.defaultCount = defaultCount
    }

    /// The catalog's own default, if it sets one.
    var explicitDefault: IngredientDefault? {
        guard let defaultUnit else { return nil }
        return IngredientDefault(unit: defaultUnit, amountOz: defaultOz, count: defaultCount)
    }

    static func customID(for name: String) -> String {
        "user-" + IngredientIndex.normalize(name).replacingOccurrences(of: " ", with: "-")
    }
}
