import XCTest
@testable import Bartender101

/// Confirms the deck actually decodes and is internally consistent. This is
/// the single most important test in the suite — everything else in the app
/// depends on `drinks.json` loading cleanly, and this project was written
/// without ever compiling on the machine that wrote it, so this is the
/// first real signal that the data survived the trip.
final class DrinkLibraryTests: XCTestCase {
    func testDeckDecodes() throws {
        let drinks = try DrinkLibrary.loadDrinks()
        XCTAssertFalse(drinks.isEmpty, "expected a non-empty deck")
    }

    func testDeckHasExpectedSize() throws {
        let drinks = try DrinkLibrary.loadDrinks()
        XCTAssertGreaterThanOrEqual(drinks.count, 60, "expected the ~62-drink working bar canon")
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
