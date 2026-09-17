import XCTest
@testable import Bartender101

@MainActor
final class CustomDrinkStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("custom_drinks_\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    /// Whole seconds, because the store saves dates as ISO 8601 without
    /// fractional seconds.
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    func testSaveReloadRoundTrip() {
        let store = CustomDrinkStore(fileURL: fileURL)
        var drink = DrinkTemplates.template(for: .sour)
        drink.name = "Garden Sour"
        drink.labels = ["summer menu"]
        store.save(drink, now: now)
        store.addTasting(id: drink.id, note: TastingNote(date: now, text: "v1: too tart", rating: 3), now: now)

        let reloaded = CustomDrinkStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.drinks.count, 1)
        let loaded = reloaded.drinks[0]
        XCTAssertEqual(loaded.name, "Garden Sour")
        XCTAssertEqual(loaded.ingredients, drink.ingredients)
        XCTAssertEqual(loaded.labels, ["summer menu"])
        XCTAssertEqual(loaded.tastings.map(\.text), ["v1: too tart"])
        XCTAssertEqual(loaded.tastings.first?.rating, 3)
        XCTAssertTrue(loaded.id.hasPrefix(CustomDrink.idPrefix))
    }

    func testSaveReplacesByID() {
        let store = CustomDrinkStore(fileURL: fileURL)
        var drink = CustomDrink(name: "First")
        store.save(drink, now: now)
        drink.name = "Renamed"
        store.save(drink, now: now.addingTimeInterval(60))
        XCTAssertEqual(store.drinks.map(\.name), ["Renamed"])
        XCTAssertEqual(store.drinks[0].updatedAt, now.addingTimeInterval(60))
    }

    func testMoveChangesStageAndPersists() {
        let store = CustomDrinkStore(fileURL: fileURL)
        let drink = CustomDrink(name: "Mover")
        store.save(drink, now: now)
        store.move(id: drink.id, to: .testing, now: now)
        XCTAssertEqual(store.drinks(in: .testing).map(\.id), [drink.id])
        XCTAssertTrue(store.drinks(in: .idea).isEmpty)
        XCTAssertEqual(CustomDrinkStore(fileURL: fileURL).drinks.first?.stage, .testing)
    }

    func testDuplicateMakesNewTestingDrinkWithoutTastings() {
        let store = CustomDrinkStore(fileURL: fileURL)
        let drink = CustomDrink(name: "Original", stage: .dialedIn, tastings: [TastingNote(text: "good")])
        store.save(drink, now: now)
        let copy = store.duplicate(id: drink.id, now: now)
        XCTAssertNotNil(copy)
        XCTAssertNotEqual(copy?.id, drink.id)
        XCTAssertEqual(copy?.name, "Original v2")
        XCTAssertEqual(copy?.stage, .testing)
        XCTAssertEqual(copy?.tastings, [])
        XCTAssertEqual(store.drinks.count, 2)
    }

    func testDeleteAndDeleteAll() {
        let store = CustomDrinkStore(fileURL: fileURL)
        let a = CustomDrink(name: "A"), b = CustomDrink(name: "B")
        store.save(a, now: now)
        store.save(b, now: now)
        store.delete(id: a.id)
        XCTAssertEqual(store.drinks.map(\.name), ["B"])
        store.deleteAll()
        XCTAssertTrue(CustomDrinkStore(fileURL: fileURL).drinks.isEmpty)
    }

    func testMenuProblems() {
        var drink = CustomDrink(ingredients: [Ingredient("Gin", oz: nil)])
        XCTAssertEqual(drink.menuProblems(nameTaken: false), ["Give it a name", "Measured ingredients need an amount"])
        drink.name = "Negroni"
        XCTAssertEqual(drink.menuProblems(nameTaken: true).first, "Another drink already uses this name")
        drink.ingredients = [Ingredient("Gin", oz: 2), Ingredient("Angostura bitters", unit: .dash, dashes: 2)]
        XCTAssertEqual(drink.menuProblems(nameTaken: false), [])
    }

    func testAsDrinkIsHouseTagged() {
        let drink = CustomDrink(name: "  ", family: .tiki).asDrink()
        XCTAssertEqual(drink.tags, [.house])
        XCTAssertEqual(drink.name, "Untitled drink")
        XCTAssertEqual(drink.family, .tiki)
    }
}
