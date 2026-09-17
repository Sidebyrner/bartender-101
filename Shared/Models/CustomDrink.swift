import Foundation

/// Where a house drink is in its life, from a first idea to a spec that's on
/// the menu. Each stage is one column on the Build tab's board. Only
/// `.onMenu` drinks join the main deck (Search, Study, Stats).
enum TestStage: String, Codable, CaseIterable, Identifiable {
    case idea
    case testing
    case dialedIn
    case onMenu
    case shelved

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .idea: return "Idea"
        case .testing: return "Testing"
        case .dialedIn: return "Dialed In"
        case .onMenu: return "On the Menu"
        case .shelved: return "Shelved"
        }
    }

    var systemImage: String {
        switch self {
        case .idea: return "lightbulb"
        case .testing: return "flask"
        case .dialedIn: return "slider.horizontal.3"
        case .onMenu: return "menucard"
        case .shelved: return "archivebox"
        }
    }

    /// Still being worked on — not yet on the menu, not set aside.
    var isInTheWorks: Bool {
        switch self {
        case .idea, .testing, .dialedIn: return true
        case .onMenu, .shelved: return false
        }
    }

    /// The stage a drink usually moves to next, for one-swipe advancing.
    /// A shelved drink comes back into testing; a drink on the menu is done.
    var next: TestStage? {
        switch self {
        case .idea: return .testing
        case .testing: return .dialedIn
        case .dialedIn: return .onMenu
        case .onMenu: return nil
        case .shelved: return .testing
        }
    }
}

/// One tasting of a house drink in progress, e.g. "v2: dropped lime to ½,
/// better." Kept per drink so the history of a spec is readable later.
struct TastingNote: Codable, Identifiable, Hashable {
    let id: UUID
    let date: Date
    var text: String
    /// 1 (bad) to 5 (great), or nil if the note is just a note.
    var rating: Int?

    init(id: UUID = UUID(), date: Date = Date(), text: String, rating: Int? = nil) {
        self.id = id
        self.date = date
        self.text = text
        self.rating = rating
    }
}

/// A drink made in the Build tab. Same spec fields as `Drink`, but mutable
/// and carrying its testing state. Persisted by `CustomDrinkStore` as JSON,
/// and turned into a plain `Drink` with `asDrink()` so the recipe page,
/// scaler, drills, and shift log treat it like any other drink.
struct CustomDrink: Codable, Identifiable, Hashable {
    /// Always `custom-<uuid>`, so it can never collide with a deck id.
    let id: String
    var name: String
    var family: DrinkFamily
    var glass: GlassType
    var ice: IceType
    var method: DrinkMethod
    var ingredients: [Ingredient]
    var garnish: String
    var notes: String

    var stage: TestStage
    /// Free-form labels, e.g. "summer menu" or "needs syrup prep".
    var labels: [String]
    var tastings: [TastingNote]
    /// The deck drink this started as a riff on, if any.
    var basedOnDrinkID: String?
    let createdAt: Date
    var updatedAt: Date

    static let idPrefix = "custom-"

    static func newID() -> String { idPrefix + UUID().uuidString.lowercased() }

    init(
        id: String = CustomDrink.newID(),
        name: String = "",
        family: DrinkFamily = .misc,
        glass: GlassType = .rocks,
        ice: IceType = .cubed,
        method: DrinkMethod = .build,
        ingredients: [Ingredient] = [],
        garnish: String = "",
        notes: String = "",
        stage: TestStage = .idea,
        labels: [String] = [],
        tastings: [TastingNote] = [],
        basedOnDrinkID: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.family = family
        self.glass = glass
        self.ice = ice
        self.method = method
        self.ingredients = ingredients
        self.garnish = garnish
        self.notes = notes
        self.stage = stage
        self.labels = labels
        self.tastings = tastings
        self.basedOnDrinkID = basedOnDrinkID
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    /// Whether `query` appears in the name, a label, or an ingredient,
    /// ignoring case and accents. An empty query matches everything.
    func matches(query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return displayName.range(of: q, options: options) != nil
            || labels.contains { $0.range(of: q, options: options) != nil }
            || ingredients.contains { $0.name.range(of: q, options: options) != nil }
    }

    /// The name shown on the board and recipe page, even before one is typed.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled drink" : trimmed
    }

    func asDrink() -> Drink {
        Drink(
            id: id,
            name: displayName,
            family: family,
            glass: glass,
            ice: ice,
            method: method,
            difficulty: 2,
            tags: [.house],
            ingredients: ingredients,
            garnish: garnish,
            notes: notes
        )
    }

    /// Why this drink can't go on the menu yet — empty when it can. The same
    /// rules `scripts/validate-drinks.js` applies to the deck, minus the
    /// per-family oz band (that's a balance warning, not a blocker).
    func menuProblems(nameTaken: Bool) -> [String] {
        var problems: [String] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            problems.append("Give it a name")
        } else if nameTaken {
            problems.append("Another drink already uses this name")
        }
        let named = ingredients.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        if named.isEmpty {
            problems.append("Add at least one ingredient")
        }
        if ingredients.contains(where: { $0.name.trimmingCharacters(in: .whitespaces).isEmpty }) {
            problems.append("Every ingredient needs a name")
        }
        for ingredient in ingredients {
            if let category = DrinkTemplates.placeholderCategory(for: ingredient.name) {
                problems.append("\(category.choosePrompt) for \"\(ingredient.name)\"")
            }
        }
        if ingredients.contains(where: { $0.unit.expectsAmount && ($0.amountOz ?? 0) <= 0 }) {
            problems.append("Measured ingredients need an amount")
        }
        return problems
    }
}

extension Ingredient {
    /// Convenience for building specs in code (templates, the builder) without
    /// spelling out every optional count.
    init(_ name: String, oz: Double? = nil, unit: IngredientUnit = .oz, dashes: Int? = nil, approx: Int? = nil, spoons: Int? = nil) {
        self.init(name: name, amountOz: oz, unit: unit, dashCount: dashes, approxCount: approx, spoonCount: spoons)
    }
}
