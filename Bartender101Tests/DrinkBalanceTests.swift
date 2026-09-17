import XCTest
@testable import Bartender101

final class DrinkBalanceTests: XCTestCase {
    func testEveryFamilyTemplateIsBalanced() {
        for family in DrinkFamily.allCases {
            let template = DrinkTemplates.template(for: family)
            XCTAssertEqual(template.family, family)
            let summary = DrinkBalance.summary(for: template.ingredients, family: family, method: template.method)
            XCTAssertTrue(family.ozBand.contains(summary.totalOz), "\(family) template is \(summary.totalOz) oz")
            XCTAssertEqual(summary.warnings, [], "\(family) template has warnings")
        }
    }

    func testClassifiesCommonRoles() {
        XCTAssertEqual(DrinkBalance.role(name: "Gin", unit: .oz), .spirit)
        XCTAssertEqual(DrinkBalance.role(name: "Base spirit", unit: .oz), .spirit)
        XCTAssertEqual(DrinkBalance.role(name: "Ginger beer", unit: .topWith), .lengthener)
        XCTAssertEqual(DrinkBalance.role(name: "Sweet vermouth", unit: .oz), .modifier)
        XCTAssertEqual(DrinkBalance.role(name: "Lime juice", unit: .oz), .sour)
        XCTAssertEqual(DrinkBalance.role(name: "Honey syrup", unit: .oz), .sweet)
        XCTAssertEqual(DrinkBalance.role(name: "Egg white", unit: .oz), .dairy)
        XCTAssertEqual(DrinkBalance.role(name: "Pineapple juice", unit: .oz), .lengthener)
        XCTAssertEqual(DrinkBalance.role(name: "Angostura bitters", unit: .dash), .accent)
    }

    /// Every measured ingredient in the real deck lands in a real role, so a
    /// deck drink riffed in the builder shows a meaningful meter.
    @MainActor
    func testDeckIngredientsAreClassified() throws {
        let allowedOther: Set<String> = ["hot sauce", "worcestershire sauce", "olive brine", "pickle brine",
                                         "orange flower water", "salt", "salt and tajín", "salt and pepper"]
        let drinks = try DrinkLibrary.loadDrinks()
        var unclassified = Set<String>()
        for ingredient in drinks.flatMap(\.ingredients) where ingredient.amountOz != nil {
            if DrinkBalance.role(name: ingredient.name, unit: ingredient.unit) == .other,
               !allowedOther.contains(ingredient.name.lowercased()) {
                unclassified.insert(ingredient.name)
            }
        }
        XCTAssertEqual(unclassified, [], "ingredients with no flavor role")
    }

    func testWarnings() {
        let stirredSour = DrinkBalance.summary(
            for: [Ingredient("Gin", oz: 2), Ingredient("Lemon juice", oz: 0.75), Ingredient("Simple syrup", oz: 0.75)],
            family: .sour, method: .stir)
        XCTAssertEqual(stirredSour.warnings, ["Citrus, cream, and egg get shaken — stirring won't mix them"])

        let noCitrus = DrinkBalance.summary(for: [Ingredient("Gin", oz: 2), Ingredient("Simple syrup", oz: 0.75)],
                                            family: .sour, method: .shake)
        XCTAssertEqual(noCitrus.warnings, ["A sour needs citrus"])

        let tart = DrinkBalance.summary(for: [Ingredient("Gin", oz: 2), Ingredient("Lime juice", oz: 1)],
                                        family: .sour, method: .shake)
        XCTAssertEqual(tart.warnings, ["Citrus with nothing sweet will drink very tart"])

        let tooBig = DrinkBalance.summary(for: [Ingredient("Rye whiskey", oz: 4), Ingredient("Sweet vermouth", oz: 2)],
                                          family: .manhattan, method: .stir)
        XCTAssertEqual(tooBig.totalOz, 6)
        XCTAssertEqual(tooBig.warnings.count, 1)
        XCTAssertTrue(tooBig.warnings[0].hasPrefix("6 oz is long"))

        let noBooze = DrinkBalance.summary(for: [Ingredient("Orange juice", oz: 4)], family: .highball, method: .build)
        XCTAssertEqual(noBooze.warnings, ["No spirit or liqueur yet"])

        XCTAssertEqual(DrinkBalance.summary(for: [], family: .sour, method: .shake).warnings, [])
    }

    /// The rules of thumb shouldn't nag about the classics: nearly every deck
    /// drink should pass clean.
    @MainActor
    func testDeckMostlyPassesWarnings() throws {
        let drinks = try DrinkLibrary.loadDrinks()
        let flagged = drinks.filter {
            !DrinkBalance.summary(for: $0.ingredients, family: $0.family, method: $0.method).warnings.isEmpty
        }
        let report = flagged.map { "\($0.name): \(DrinkBalance.summary(for: $0.ingredients, family: $0.family, method: $0.method).warnings)" }
        XCTAssertLessThanOrEqual(flagged.count, drinks.count / 20, report.joined(separator: "\n"))
    }

    func testRiffCopiesSpecAndSource() {
        let negroni = Drink.stub(id: "negroni", family: .manhattan, method: .stir)
        let riff = DrinkTemplates.riff(on: negroni)
        XCTAssertEqual(riff.basedOnDrinkID, "negroni")
        XCTAssertEqual(riff.ingredients, negroni.ingredients)
        XCTAssertEqual(riff.stage, .idea)
        XCTAssertEqual(riff.name, "")
    }
}
