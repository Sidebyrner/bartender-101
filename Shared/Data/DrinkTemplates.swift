import Foundation

/// Starting points for the drink builder. A template is the classic ratio
/// for a family with generic names ("Base spirit") to swap for real bottles;
/// a riff is a copy of a deck drink to change. Pure, so every template is
/// checked against its family's oz band and `DrinkBalance` in tests.
enum DrinkTemplates {
    /// Generic names templates use for "fill this in", and the shelf to pick
    /// the real ingredient from. The builder shows these as "Choose a
    /// spirit" prompts, and a drink can't go on the menu with one left.
    static let placeholders: [String: IngredientCategory] = [
        "base spirit": .spirits,
        "mixer": .mixers,
        "liqueur": .liqueurs,
        "bitter liqueur": .vermouthAmari,
        "lemon or lime juice": .citrus,
    ]

    static func placeholderCategory(for name: String) -> IngredientCategory? {
        placeholders[name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
    }

    static func template(for family: DrinkFamily) -> CustomDrink {
        switch family {
        case .highball:
            return CustomDrink(family: family, glass: .highball, ice: .cubed, method: .build, ingredients: [
                Ingredient("Base spirit", oz: 2),
                Ingredient("Mixer", oz: 4, unit: .topWith),
            ], garnish: "Citrus wedge", notes: "2 oz spirit, top with mixer — the template for every well highball.")
        case .mule:
            return CustomDrink(family: family, glass: .copperMug, ice: .cubed, method: .build, ingredients: [
                Ingredient("Base spirit", oz: 2),
                Ingredient("Lime juice", oz: 0.5),
                Ingredient("Ginger beer", oz: 4, unit: .topWith),
            ], garnish: "Lime wedge", notes: "Spirit, a little lime, top with ginger beer.")
        case .sour:
            return CustomDrink(family: family, glass: .coupe, ice: .none, method: .shake, ingredients: [
                Ingredient("Base spirit", oz: 2),
                Ingredient("Lemon or lime juice", oz: 0.75),
                Ingredient("Simple syrup", oz: 0.75),
            ], garnish: "Citrus peel", notes: "2 : ¾ : ¾ — spirit, citrus, sweet. Swap the syrup for a liqueur to riff.")
        case .oldFashioned:
            return CustomDrink(family: family, glass: .rocks, ice: .largeCube, method: .stir, ingredients: [
                Ingredient("Base spirit", oz: 2),
                Ingredient("Simple syrup", oz: 0.25),
                Ingredient("Angostura bitters", unit: .dash, dashes: 2),
            ], garnish: "Orange peel, expressed", notes: "Spirit, a touch of sugar, bitters. Try a flavored syrup or different bitters.")
        case .martini:
            return CustomDrink(family: family, glass: .martini, ice: .none, method: .stir, ingredients: [
                Ingredient("Base spirit", oz: 2.5),
                Ingredient("Dry vermouth", oz: 0.5),
                Ingredient("Orange bitters", unit: .dash, dashes: 1),
            ], garnish: "Lemon twist", notes: "5 : 1 spirit to dry vermouth. Stirred, served up.")
        case .manhattan:
            return CustomDrink(family: family, glass: .coupe, ice: .none, method: .stir, ingredients: [
                Ingredient("Base spirit", oz: 2),
                Ingredient("Sweet vermouth", oz: 1),
                Ingredient("Angostura bitters", unit: .dash, dashes: 2),
            ], garnish: "Cherry", notes: "2 : 1 spirit to sweet vermouth. Swap the vermouth for an amaro to riff.")
        case .spritz:
            return CustomDrink(family: family, glass: .wine, ice: .cubed, method: .build, ingredients: [
                Ingredient("Bitter liqueur", oz: 2),
                Ingredient("Prosecco", oz: 3, unit: .topWith),
                Ingredient("Soda water", oz: 1, unit: .splash),
            ], garnish: "Orange slice", notes: "3 : 2 : 1 — sparkling wine, bitter liqueur, soda.")
        case .tiki:
            return CustomDrink(family: family, glass: .tikiMug, ice: .crushed, method: .shake, ingredients: [
                Ingredient("Base spirit", oz: 2),
                Ingredient("Lime juice", oz: 1),
                Ingredient("Orgeat", oz: 0.5),
                Ingredient("Orange curaçao", oz: 0.5),
            ], garnish: "Mint sprig", notes: "A sour with more going on — split the base, add a spice syrup.")
        case .muddled:
            return CustomDrink(family: family, glass: .collins, ice: .crushed, method: .muddle, ingredients: [
                Ingredient("Mint leaves", unit: .muddled, approx: 8),
                Ingredient("Simple syrup", oz: 0.75),
                Ingredient("Lime juice", oz: 0.75),
                Ingredient("Base spirit", oz: 2),
                Ingredient("Soda water", oz: 2, unit: .topWith),
            ], garnish: "Mint sprig", notes: "Muddle gently, build over crushed ice, top with soda.")
        case .cream:
            return CustomDrink(family: family, glass: .coupe, ice: .none, method: .shake, ingredients: [
                Ingredient("Base spirit", oz: 1),
                Ingredient("Liqueur", oz: 1),
                Ingredient("Heavy cream", oz: 1),
            ], garnish: "Grated nutmeg", notes: "Equal parts spirit, liqueur, and cream, shaken hard.")
        case .shot:
            return CustomDrink(family: family, glass: .shot, ice: .none, method: .shake, ingredients: [
                Ingredient("Base spirit", oz: 1),
                Ingredient("Liqueur", oz: 0.5),
            ], garnish: "None", notes: "Shaken and strained into a shot glass.")
        case .misc:
            return CustomDrink(family: family, glass: .rocks, ice: .cubed, method: .build, ingredients: [
                Ingredient("Base spirit", oz: 2),
            ], garnish: "", notes: "")
        }
    }

    /// An empty spec with sensible pickers, for starting from nothing.
    static func blank() -> CustomDrink {
        CustomDrink()
    }

    /// A copy of a deck (or house) drink to change, remembering where it came
    /// from.
    static func riff(on drink: Drink) -> CustomDrink {
        CustomDrink(
            name: "",
            family: drink.family,
            glass: drink.glass,
            ice: drink.ice,
            method: drink.method,
            ingredients: drink.ingredients,
            garnish: drink.garnish,
            notes: "Riff on the \(drink.name).",
            basedOnDrinkID: drink.id
        )
    }
}
