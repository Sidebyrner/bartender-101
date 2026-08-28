import XCTest
@testable import Bartender101

final class MeasureTests: XCTestCase {
    func testOzToMlUsesBarStandardRounding() {
        // 30 ml/oz, rounded to the nearest 2.5 ml — matches what's etched
        // on a real jigger, not the precise 29.57 ml/oz conversion.
        XCTAssertEqual(Measure.milliliters(fromOz: 1), 30)
        XCTAssertEqual(Measure.milliliters(fromOz: 0.75), 22.5)
        XCTAssertEqual(Measure.milliliters(fromOz: 1.5), 45)
        XCTAssertEqual(Measure.milliliters(fromOz: 0.25), 7.5)
        XCTAssertEqual(Measure.milliliters(fromOz: 2), 60)
    }

    func testOzFractionFormatting() {
        XCTAssertEqual(Measure.ozFraction(2), "2")
        XCTAssertEqual(Measure.ozFraction(0.75), "¾")
        XCTAssertEqual(Measure.ozFraction(1.5), "1½")
        XCTAssertEqual(Measure.ozFraction(0.25), "¼")
        XCTAssertEqual(Measure.ozFraction(0), "0")
    }

    func testLabelRespectsUnit() {
        XCTAssertEqual(Measure.label(oz: 2, unit: .oz), "2 oz")
        XCTAssertEqual(Measure.label(oz: 1, unit: .ml), "30 ml")
        XCTAssertEqual(Measure.label(oz: 0.75, unit: .ml), "22.5 ml")
    }

    func testFuzzyMatchAcceptsCloseTypos() {
        XCTAssertTrue(FuzzyMatch.matches(input: "mojito", target: "Mojito"))
        XCTAssertTrue(FuzzyMatch.matches(input: "mohito", target: "Mojito"))
        XCTAssertTrue(FuzzyMatch.matches(input: "negroni", target: "Negroni"))
        XCTAssertFalse(FuzzyMatch.matches(input: "margarita", target: "Negroni"))
        XCTAssertFalse(FuzzyMatch.matches(input: "", target: "Negroni"))
    }
}
