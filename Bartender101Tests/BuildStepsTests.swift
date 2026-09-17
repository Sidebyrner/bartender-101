import XCTest
@testable import Bartender101

final class BuildStepsTests: XCTestCase {
    func testShakenUpStrainsIntoChilledGlass() {
        XCTAssertEqual(
            BuildSteps.methodLines(method: .shake, glass: .coupe, ice: .none),
            ["Shake hard with ice", "Strain up into a chilled coupe"]
        )
    }

    func testStirredOverLargeCube() {
        XCTAssertEqual(
            BuildSteps.methodLines(method: .stir, glass: .rocks, ice: .largeCube),
            ["Stir with ice, about 20 seconds", "Strain into a rocks glass over a fresh large cube"]
        )
    }

    func testShotStrainsIntoShotGlass() {
        XCTAssertEqual(BuildSteps.methodLines(method: .shake, glass: .shot, ice: .none).last, "Strain into a shot glass")
    }

    func testBuiltAndLayeredFollowPourOrder() {
        XCTAssertEqual(BuildSteps.methodLines(method: .build, glass: .highball, ice: .cubed), ["Build in the glass, in pour order"])
        XCTAssertEqual(BuildSteps.methodLines(method: .layer, glass: .shot, ice: .none), ["Layer slowly over the back of a barspoon, in pour order"])
    }

    func testArticleBeforeVowel() {
        XCTAssertEqual(BuildSteps.methodLines(method: .blend, glass: .irishCoffeeMug, ice: .crushed).last, "Pour into an Irish coffee mug")
    }
}
