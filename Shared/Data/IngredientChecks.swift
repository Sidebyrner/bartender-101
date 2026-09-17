import Foundation

/// The builder's per-row safeguards: a unit that doesn't fit the ingredient
/// (2 oz of Angostura, "top with" gin) and the same ingredient listed twice.
/// Pure functions; every rule is checked against the whole deck in tests so
/// none of them fire on a real spec.
enum IngredientChecks {
    struct UnitIssue: Equatable {
        let message: String
        /// A corrected ingredient to apply with one tap, or nil when the
        /// issue is a heads-up rather than a clear mistake.
        let fix: Ingredient?
        /// A short label for the fix button.
        let fixLabel: String?
    }

    static func unitIssue(for ingredient: Ingredient, category: IngredientCategory?) -> UnitIssue? {
        guard let category else { return nil }
        let name = ingredient.name
        let oz = ingredient.amountOz ?? 0

        switch category {
        case .bitters:
            if ingredient.unit == .oz && oz > 1.5 {
                return UnitIssue(
                    message: "\(Measure.ozFraction(oz)) oz of \(name) is a lot — bitters usually go in by the dash",
                    fix: IngredientDefault(unit: .dash, count: 2).ingredient(named: name),
                    fixLabel: "Use 2 dashes")
            }
            if ingredient.unit == .topWith || ingredient.unit == .splash {
                return UnitIssue(
                    message: "Bitters go in by the dash, not as a top",
                    fix: IngredientDefault(unit: .dash, count: 2).ingredient(named: name),
                    fixLabel: "Use 2 dashes")
            }

        case .spirits, .liqueurs, .vermouthAmari:
            if ingredient.unit == .topWith || ingredient.unit == .splash {
                return UnitIssue(
                    message: "\(name) is usually measured, not used to top a drink",
                    fix: IngredientDefault(unit: .oz, amountOz: category == .spirits ? 2 : 0.5).ingredient(named: name),
                    fixLabel: category == .spirits ? "Use 2 oz" : "Use ½ oz")
            }
            if category == .spirits && ingredient.unit == .oz && oz > 4 {
                return UnitIssue(message: "\(Measure.ozFraction(oz)) oz of \(name) is a lot for one drink", fix: nil, fixLabel: nil)
            }

        case .mixers, .wineBeer, .juices:
            if [.dash, .barspoon, .pinch, .muddled].contains(ingredient.unit) {
                let fix = category == .juices
                    ? IngredientDefault(unit: .oz, amountOz: 1)
                    : IngredientDefault(unit: .topWith, amountOz: 4)
                return UnitIssue(
                    message: "\(name) is a pour, not a \(ingredient.unit.pickerName.lowercased())",
                    fix: fix.ingredient(named: name),
                    fixLabel: category == .juices ? "Use 1 oz" : "Top with")
            }

        case .herbsFruit:
            if ingredient.unit == .oz || ingredient.unit == .topWith || ingredient.unit == .splash {
                return UnitIssue(
                    message: "\(name) gets muddled, not measured in ounces",
                    fix: IngredientDefault(unit: .muddled, count: 4).ingredient(named: name),
                    fixLabel: "Muddle")
            }

        case .citrus:
            if ingredient.unit == .oz && oz > 3 {
                return UnitIssue(message: "\(Measure.ozFraction(oz)) oz of \(name) will be very sour", fix: nil, fixLabel: nil)
            }
            if ingredient.unit == .topWith {
                return UnitIssue(
                    message: "Citrus is measured, not used to top a drink",
                    fix: IngredientDefault(unit: .oz, amountOz: 0.75).ingredient(named: name),
                    fixLabel: "Use ¾ oz")
            }

        case .syrups, .dairyEgg, .seasoning:
            break
        }
        return nil
    }

    /// Groups of row positions that hold the same ingredient, by catalog
    /// identity when known ("Angostura" and "Angostura bitters") or by
    /// normalized name otherwise. Only groups of two or more are returned.
    static func duplicateGroups(in ingredients: [Ingredient], index: IngredientIndex) -> [[Int]] {
        var groups: [String: [Int]] = [:]
        var order: [String] = []
        for (position, ingredient) in ingredients.enumerated() {
            let name = ingredient.name.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, DrinkTemplates.placeholderCategory(for: name) == nil else { continue }
            let key = index.resolve(name)?.id ?? IngredientIndex.normalize(name)
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(position)
        }
        return order.compactMap { groups[$0] }.filter { $0.count > 1 }
    }

    /// Whether two lines can be merged into one by adding their amounts.
    static func canCombine(_ a: Ingredient, _ b: Ingredient) -> Bool {
        a.unit == b.unit
    }

    /// One line holding both amounts (or counts), keeping the first's name.
    static func combine(_ a: Ingredient, _ b: Ingredient) -> Ingredient {
        func add(_ x: Int?, _ y: Int?) -> Int? {
            x == nil && y == nil ? nil : (x ?? 0) + (y ?? 0)
        }
        return Ingredient(
            name: a.name,
            amountOz: a.amountOz == nil && b.amountOz == nil ? nil : (a.amountOz ?? 0) + (b.amountOz ?? 0),
            unit: a.unit,
            dashCount: add(a.dashCount, b.dashCount),
            approxCount: add(a.approxCount, b.approxCount),
            spoonCount: add(a.spoonCount, b.spoonCount)
        )
    }
}
