import XCTest
@testable import Bartender101

/// Confirms the deck actually decodes and is internally consistent. This is
/// the single most important test in the suite — everything else in the app
/// depends on `drinks.json` loading cleanly, and this project was written
/// without ever compiling on the machine that wrote it, so this is the
/// first real signal that the data survived the trip.
@MainActor
final class DrinkLibraryTests: XCTestCase {
    func testDeckDecodes() throws {
        let drinks = try DrinkLibrary.loadDrinks()
        XCTAssertFalse(drinks.isEmpty, "expected a non-empty deck")
    }

    func testDeckHasExpectedSize() throws {
        let drinks = try DrinkLibrary.loadDrinks()
        XCTAssertGreaterThanOrEqual(drinks.count, 180, "expected the full ~180-drink deck")
    }

    func testNoDuplicateIDs() throws {
        let drinks = try DrinkLibrary.loadDrinks()
        let ids = drinks.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "found duplicate drink ids")
    }

    func testNoDuplicateNames() throws {
        let drinks = try DrinkLibrary.loadDrinks()
        let names = drinks.map(\.name)
        XCTAssertEqual(names.count, Set(names).count, "found duplicate drink names")
    }

    func testEveryDrinkHasIngredients() throws {
        let drinks = try DrinkLibrary.loadDrinks()
        for drink in drinks {
            XCTAssertFalse(drink.ingredients.isEmpty, "\(drink.name) has no ingredients")
        }
    }

    func testEveryDrinkHasNotesAndGarnish() throws {
        let drinks = try DrinkLibrary.loadDrinks()
        for drink in drinks {
            XCTAssertFalse(drink.notes.isEmpty, "\(drink.name) is missing notes")
            XCTAssertFalse(drink.garnish.isEmpty, "\(drink.name) is missing a garnish")
        }
    }

    func testNoDuplicateIngredientsWithinADrink() throws {
        let drinks = try DrinkLibrary.loadDrinks()
        for drink in drinks {
            let names = drink.ingredients.map(\.name)
            XCTAssertEqual(names.count, Set(names).count, "\(drink.name) lists an ingredient twice")
        }
    }

    @MainActor
    func testLibrarySearchFindsByName() {
        let library = DrinkLibrary()
        let results = library.search("negroni")
        XCTAssertTrue(results.contains { $0.id == "negroni" })
    }

    @MainActor
    func testLibrarySearchFindsByIngredient() {
        let library = DrinkLibrary()
        let results = library.search("campari")
        XCTAssertTrue(results.contains { $0.id == "negroni" })
        XCTAssertTrue(results.contains { $0.id == "boulevardier" })
    }

    @MainActor
    func testDistractorsExcludeTheDrinkItself() {
        let library = DrinkLibrary()
        guard let negroni = library.drink(id: "negroni") else {
            return XCTFail("negroni missing from deck")
        }
        let distractors = library.distractors(for: negroni, count: 3)
        XCTAssertEqual(distractors.count, 3)
        XCTAssertFalse(distractors.contains(negroni))
    }

    @MainActor
    func testDistractorsPreferSameFamily() {
        let library = DrinkLibrary()
        guard let negroni = library.drink(id: "negroni") else {
            return XCTFail("negroni missing from deck")
        }
        // The manhattan family (Negroni's family) has 5 members, so 3
        // distractors should always be satisfiable from within it.
        let distractors = library.distractors(for: negroni, count: 3)
        XCTAssertTrue(distractors.allSatisfy { $0.family == .manhattan })
    }
}

@MainActor
final class DrinkLibraryCustomDrinkTests: XCTestCase {
    func testOnlyOnMenuHouseDrinksJoinTheDeck() {
        let library = DrinkLibrary(deck: [Drink.stub(id: "negroni")])
        let idea = CustomDrink(name: "Idea Drink", family: .sour, stage: .idea)
        let menu = CustomDrink(name: "Menu Drink", family: .sour, stage: .onMenu)
        library.setCustomDrinks([idea, menu])

        XCTAssertEqual(Set(library.drinks.map(\.id)), ["negroni", menu.id])
        XCTAssertEqual(library.drinks(in: .sour).map(\.id), [menu.id])
        XCTAssertEqual(library.search("menu drink").map(\.id), [menu.id])
        XCTAssertEqual(library.drink(id: idea.id)?.name, "Idea Drink", "test drinks still resolve by id")
        XCTAssertEqual(library.drinks(matchingTags: [.house]).map(\.id), [menu.id])

        library.setCustomDrinks([])
        XCTAssertEqual(library.drinks.map(\.id), ["negroni"])
        XCTAssertNil(library.drink(id: idea.id))
    }

    func testNameTakenChecksDeckAndOtherHouseDrinks() {
        let library = DrinkLibrary(deck: [Drink.stub(id: "Negroni")])
        let house = CustomDrink(name: "Garden Sour")
        library.setCustomDrinks([house])
        XCTAssertTrue(library.isNameTaken("negroni"))
        XCTAssertTrue(library.isNameTaken(" garden sour "))
        XCTAssertFalse(library.isNameTaken("Garden Sour", excluding: house.id))
        XCTAssertFalse(library.isNameTaken(""))
    }
}
