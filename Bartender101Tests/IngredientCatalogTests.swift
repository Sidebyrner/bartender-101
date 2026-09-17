import XCTest
@testable import Bartender101

@MainActor
final class IngredientCatalogTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("ingredients_\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    private func makeCatalog() throws -> IngredientCatalog {
        let catalog = IngredientCatalog(bundled: try IngredientIndex.loadBundled(), fileURL: fileURL)
        catalog.learn(fromDeck: try DrinkLibrary.loadDrinks())
        return catalog
    }

    func testBundledCatalogDecodesWithUniqueKeys() throws {
        let entries = try IngredientIndex.loadBundled()
        XCTAssertGreaterThan(entries.count, 200)
        XCTAssertEqual(Set(entries.map(\.id)).count, entries.count, "duplicate ids")
        var seen: [String: String] = [:]
        for entry in entries {
            for key in [entry.name] + entry.aliases {
                let normalized = IngredientIndex.normalize(key)
                XCTAssertNil(seen[normalized], "\"\(key)\" on \(entry.name) also belongs to \(seen[normalized] ?? "")")
                seen[normalized] = entry.name
            }
        }
    }

    /// Every name the deck uses is on the shelf, so riffs on deck drinks get
    /// categories, icons, and unit checks.
    func testEveryDeckIngredientResolves() throws {
        let index = IngredientIndex(entries: try IngredientIndex.loadBundled())
        let missing = Set(try DrinkLibrary.loadDrinks().flatMap(\.ingredients).map(\.name).filter { index.resolve($0) == nil })
        XCTAssertEqual(missing, [])
    }

    /// Template ingredients are either real catalog names or known stand-ins.
    func testTemplateIngredientsAreKnown() throws {
        let index = IngredientIndex(entries: try IngredientIndex.loadBundled())
        for family in DrinkFamily.allCases {
            for ingredient in DrinkTemplates.template(for: family).ingredients {
                XCTAssertTrue(index.resolve(ingredient.name) != nil || DrinkTemplates.placeholderCategory(for: ingredient.name) != nil,
                              "\(family): \(ingredient.name)")
            }
        }
    }

    func testSearchRanking() throws {
        let catalog = try makeCatalog()
        XCTAssertEqual(catalog.search("lime").prefix(2).map(\.entry.name), ["Lime", "Lime juice"],
                       "the exact name first, then the most-used lime ingredient")
        XCTAssertEqual(catalog.search("lime jiuce").first?.entry.name, "Lime juice")
        XCTAssertEqual(catalog.search("limejuice").first?.entry.name, "Lime juice")
        XCTAssertEqual(catalog.search("OJ").first?.entry.name, "Orange juice")
        XCTAssertEqual(catalog.search("creme de cassis").first?.entry.name, "Crème de cassis")
        XCTAssertEqual(catalog.search("kahlua").first?.entry.name, "Coffee liqueur")
        XCTAssertEqual(catalog.search("angostra").first?.entry.name, "Angostura bitters")
        XCTAssertEqual(catalog.search("gin").first?.entry.name, "Gin", "an exact name beats Ginger beer")
        XCTAssertTrue(catalog.search("OJ").first?.isExact ?? false)
        XCTAssertFalse(catalog.search("lim").contains { $0.isExact })
        XCTAssertTrue(catalog.search("rum", category: .spirits).allSatisfy { $0.entry.category == .spirits })
        XCTAssertTrue(catalog.search("zzqx").isEmpty)
    }

    func testDidYouMean() throws {
        let catalog = try makeCatalog()
        XCTAssertTrue(catalog.didYouMean("campary").map(\.name).contains("Campari"))
        XCTAssertEqual(catalog.didYouMean("Campari"), [], "no suggestions for an exact name")
    }

    func testDefaultsFollowTheDeck() throws {
        let catalog = try makeCatalog()
        func pour(_ name: String) throws -> IngredientDefault {
            catalog.defaults(for: try XCTUnwrap(catalog.index.resolve(name)))
        }
        XCTAssertEqual(try pour("Angostura bitters").unit, .dash)
        XCTAssertEqual(try pour("Soda water").unit, .topWith)
        XCTAssertEqual(try pour("Mint leaves").unit, .muddled)
        XCTAssertEqual(try pour("Lime juice").unit, .oz)
        XCTAssertTrue([0.5, 0.75].contains(try pour("Lime juice").amountOz))
        XCTAssertEqual(try pour("Egg white").amountOz, 0.75, "the catalog's own default wins")
        XCTAssertEqual(try pour("Batavia arrack").unit, .oz, "unused in the deck: category default")
        XCTAssertGreaterThan(catalog.usageCount(for: "lime-juice"), 20)
    }

    func testCustomIngredientsAndRecentsPersist() throws {
        let catalog = try makeCatalog()
        let yuzuKosho = catalog.addCustom(name: "Yuzu kosho", category: .seasoning)
        XCTAssertEqual(catalog.addCustom(name: "yuzu KOSHO", category: .spirits).id, yuzuKosho.id, "no duplicate customs")
        XCTAssertEqual(catalog.addCustom(name: "lime juice", category: .seasoning).name, "Lime juice", "known names aren't re-added")
        catalog.noteUsed(yuzuKosho)
        catalog.noteUsed(try XCTUnwrap(catalog.index.resolve("Gin")))
        catalog.noteUsed(yuzuKosho)

        let reloaded = IngredientCatalog(bundled: try IngredientIndex.loadBundled(), fileURL: fileURL)
        XCTAssertEqual(reloaded.customIngredients.map(\.name), ["Yuzu kosho"])
        XCTAssertEqual(reloaded.recents.map(\.name), ["Yuzu kosho", "Gin"])
        XCTAssertEqual(reloaded.search("yuzu k").first?.entry.name, "Yuzu kosho")
        XCTAssertEqual(reloaded.category(for: "Yuzu kosho"), .seasoning)
    }

    func testHouseDrinkNamesBecomePickable() throws {
        let catalog = try makeCatalog()
        catalog.learn(fromHouseDrinks: [CustomDrink(ingredients: [Ingredient("Smoked honey syrup", oz: 0.5), Ingredient("Base spirit", oz: 2)])])
        XCTAssertEqual(catalog.index.resolve("smoked honey syrup")?.category, .syrups)
        XCTAssertNil(catalog.index.resolve("Base spirit"), "stand-ins aren't ingredients")
        XCTAssertEqual(catalog.category(for: "Base spirit"), .spirits)
    }

    func testReplacementKeepsPourOnlyWhenMeasuredTheSameWay() {
        let lime = Ingredient("Lime juice", oz: 0.75)
        let lemon = IngredientPickerSheet.replacement(for: lime, with: "Lemon juice", pour: IngredientDefault(unit: .oz, amountOz: 0.5))
        XCTAssertEqual(lemon, Ingredient("Lemon juice", oz: 0.75))
        let bitters = IngredientPickerSheet.replacement(for: lime, with: "Angostura bitters", pour: IngredientDefault(unit: .dash, count: 2))
        XCTAssertEqual(bitters, Ingredient("Angostura bitters", unit: .dash, dashes: 2))
    }
}
