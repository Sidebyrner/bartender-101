import XCTest
@testable import Bartender101

final class InventionHelpersTests: XCTestCase {
    private func line(_ name: String, _ oz: Double, _ unit: IngredientUnit = .oz) -> Ingredient {
        Ingredient(name: name, amountOz: oz, unit: unit, dashCount: nil, approxCount: nil, spoonCount: nil)
    }

    func testReferenceDataLoads() throws {
        let reference = try ReferenceLibrary.load()
        XCTAssertGreaterThan(reference.drinks.count, 300)
        XCTAssertGreaterThan(reference.pairings.count, 50)
        XCTAssertNotNil(reference.profiles[.sour])
        XCTAssertEqual(Set(reference.drinks.map(\.id)).count, reference.drinks.count, "duplicate reference ids")
    }

    /// The import script only keeps recipes whose every ingredient is in the
    /// catalog, so pairing, balance, and similarity all see real names.
    func testEveryReferenceIngredientIsInTheCatalog() throws {
        let reference = try ReferenceLibrary.load()
        var unknown = Set<String>()
        for ingredient in reference.drinks.flatMap(\.ingredients) where IngredientIndex.bundled.resolve(ingredient.name) == nil {
            unknown.insert(ingredient.name)
        }
        XCTAssertEqual(unknown, [])
        for drink in reference.drinks {
            for ingredient in drink.ingredients where ingredient.unit.expectsAmount {
                XCTAssertGreaterThan(ingredient.amountOz ?? 0, 0, "\(drink.name): \(ingredient.name) has no amount")
            }
        }
    }

    func testPairingsSuggestPartnersNotAlreadyInTheDrink() {
        let drink = [line("Gin", 2), line("Lime juice", 0.75)]
        let suggestions = InventionHelpers.pairings(for: drink)
        XCTAssertFalse(suggestions.isEmpty)
        let names = Set(suggestions.map(\.name))
        XCTAssertFalse(names.contains("Gin"))
        XCTAssertFalse(names.contains("Lime juice"))
        for suggestion in suggestions {
            XCTAssertFalse(suggestion.pairedWith.isEmpty)
            XCTAssertTrue(suggestion.reason.hasPrefix("With "))
        }
    }

    func testPairingsIgnoreTemplatePlaceholders() {
        XCTAssertEqual(InventionHelpers.pairings(for: [line("Base spirit", 2)]), [])
        XCTAssertEqual(InventionHelpers.pairings(for: []), [])
    }

    func testSourTemplateRatioIsTypicalAndDoubledCitrusIsFlagged() throws {
        let template = DrinkTemplates.template(for: .sour)
        let summary = DrinkBalance.summary(for: template.ingredients, family: .sour, method: .shake)
        let check = try XCTUnwrap(InventionHelpers.ratioCheck(summary: summary, family: .sour))
        XCTAssertEqual(check.notes, [], "the classic 2 : ¾ : ¾ should read as typical")

        let tart = [line("Gin", 2), line("Lime juice", 1.5), line("Simple syrup", 0.75)]
        let tartSummary = DrinkBalance.summary(for: tart, family: .sour, method: .shake)
        let tartCheck = try XCTUnwrap(InventionHelpers.ratioCheck(summary: tartSummary, family: .sour))
        XCTAssertTrue(tartCheck.notes.contains { $0.role == .sour && $0.direction == .high })
    }

    func testRatioCheckWaitsForTwoRolesAndSkipsMisc() {
        let empty = DrinkBalance.summary(for: [], family: .sour, method: .shake)
        XCTAssertNil(InventionHelpers.ratioCheck(summary: empty, family: .sour))
        let loneSpirit = DrinkBalance.summary(for: [line("Gin", 2)], family: .sour, method: .shake)
        XCTAssertNil(InventionHelpers.ratioCheck(summary: loneSpirit, family: .sour))
        let misc = DrinkBalance.summary(for: [line("Gin", 2), line("Lemon juice", 0.75)], family: .misc, method: .shake)
        XCTAssertNil(InventionHelpers.ratioCheck(summary: misc, family: .misc))
    }

    func testSimilarityIsOneForTheSameSpecAndZeroForNothingShared() {
        let a = InventionHelpers.profile(of: [line("Gin", 2), line("Lime juice", 1)])
        let b = InventionHelpers.profile(of: [line("Bourbon", 2), line("Sweet vermouth", 1)])
        XCTAssertEqual(InventionHelpers.similarity(a, a), 1, accuracy: 0.0001)
        XCTAssertEqual(InventionHelpers.similarity(a, b), 0, accuracy: 0.0001)
    }

    @MainActor
    func testDaiquiriSpecFindsTheDaiquiri() throws {
        let deck = try DrinkLibrary.loadDrinks()
        let spec = [line("White rum", 2), line("Lime juice", 1), line("Simple syrup", 0.75)]
        let matches = InventionHelpers.closeMatches(for: spec, deck: deck)
        let top = try XCTUnwrap(matches.first)
        XCTAssertTrue(top.drink.name.localizedCaseInsensitiveContains("daiquiri"), "top match was \(top.drink.name)")
        XCTAssertGreaterThan(top.similarity, 0.7)
    }

    func testCloseMatchesNeedTwoIngredients() {
        XCTAssertEqual(InventionHelpers.closeMatches(for: [line("Gin", 2)], deck: []), [])
    }

    @MainActor
    func testNegroniHasDocumentedRiffs() throws {
        let deck = try DrinkLibrary.loadDrinks()
        let negroni = try XCTUnwrap(deck.first { $0.name == "Negroni" })
        let riffs = InventionHelpers.riffs(of: negroni)
        XCTAssertFalse(riffs.isEmpty)
        XCTAssertFalse(riffs.contains { $0.name == "Negroni" })
        XCTAssertTrue(riffs.contains { $0.name.localizedCaseInsensitiveContains("negroni") || $0.parent == "Negroni" })
    }

    func testRiffOnReferenceDrinkCopiesSpecWithoutDeckLink() throws {
        let reference = try ReferenceLibrary.load()
        let source = try XCTUnwrap(reference.drinks.first)
        let riff = DrinkTemplates.riff(on: source)
        XCTAssertEqual(riff.ingredients, source.ingredients)
        XCTAssertEqual(riff.family, source.family)
        XCTAssertNil(riff.basedOnDrinkID)
        XCTAssertTrue(riff.id.hasPrefix(CustomDrink.idPrefix))
    }
}
