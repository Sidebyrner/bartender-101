import XCTest
@testable import Bartender101

final class ShiftLogTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    private func entry(_ drinkID: String, at madeAt: Date, servings: Double = 1, totalOz: Double = 3) -> MadeDrink {
        MadeDrink(id: UUID(), drinkID: drinkID, drinkName: drinkID.capitalized, madeAt: madeAt,
                  servings: servings, batchMode: false, unit: .oz, totalOz: totalOz)
    }

    func testAfterMidnightCountsTowardPreviousNight() {
        XCTAssertEqual(ShiftLog.shiftDay(for: date(19, 1, 30), calendar: calendar), date(18, 0))
        XCTAssertEqual(ShiftLog.shiftDay(for: date(19, 4, 0), calendar: calendar), date(19, 0))
        XCTAssertEqual(ShiftLog.shiftDay(for: date(18, 21), calendar: calendar), date(18, 0))
    }

    func testNightsGroupAcrossMidnightNewestFirst() {
        let entries = [
            entry("margarita", at: date(18, 22)),
            entry("mojito", at: date(19, 1)),
            entry("negroni", at: date(19, 23)),
        ]
        let nights = ShiftLog.nights(from: entries, calendar: calendar)
        XCTAssertEqual(nights.map(\.date), [date(19, 0), date(18, 0)])
        XCTAssertEqual(nights[1].entries.map(\.drinkID), ["mojito", "margarita"])
    }

    func testNightTotalsAndTally() {
        let entries = [
            entry("margarita", at: date(18, 22), servings: 2, totalOz: 8),
            entry("mojito", at: date(18, 23), totalOz: 3.5),
            entry("margarita", at: date(18, 23, 30), totalOz: 4),
        ]
        let night = ShiftLog.nights(from: entries, calendar: calendar)[0]
        XCTAssertEqual(night.drinkCount, 3)
        XCTAssertEqual(night.totalServings, 4)
        XCTAssertEqual(night.totalOz, 15.5)
        XCTAssertEqual(night.tally.map(\.drinkID), ["margarita", "mojito"])
        XCTAssertEqual(night.tally[0].count, 2)
        XCTAssertEqual(night.tally[0].servings, 3)
    }

    func testTonightIsNilWithNothingLogged() {
        let entries = [entry("margarita", at: date(17, 22))]
        XCTAssertNil(ShiftLog.tonight(from: entries, now: date(18, 22), calendar: calendar))
        XCTAssertNotNil(ShiftLog.tonight(from: entries, now: date(18, 2), calendar: calendar))
    }

    func testTotalOzScalesAndAddsBatchWater() {
        let drink = Drink.stub(method: .shake, ingredients: [
            Ingredient(name: "Gin", amountOz: 2, unit: .oz, dashCount: nil, approxCount: nil, spoonCount: nil),
            Ingredient(name: "Lime juice", amountOz: 1, unit: .oz, dashCount: nil, approxCount: nil, spoonCount: nil),
            Ingredient(name: "Angostura bitters", amountOz: nil, unit: .dash, dashCount: 2, approxCount: nil, spoonCount: nil),
        ])
        XCTAssertEqual(ShiftLog.totalOz(for: drink, servings: 2, batchMode: false), 6)
        XCTAssertEqual(ShiftLog.totalOz(for: drink, servings: 2, batchMode: true), 6 * 1.30, accuracy: 0.001)
    }

    @MainActor
    func testStorePersistsRecordAndRemove() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("shift_log_test_\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = ShiftLogStore(fileURL: url)
        let drink = Drink.stub(id: "gimlet")
        let kept = store.record(drink: drink, servings: 2, batchMode: false, unit: .ml)
        let removed = store.record(drink: drink, servings: 1, batchMode: false, unit: .oz)
        store.remove(id: removed.id)

        let reloaded = ShiftLogStore(fileURL: url)
        XCTAssertEqual(reloaded.entries.map(\.id), [kept.id])
        XCTAssertEqual(reloaded.entries.first?.servings, 2)
        XCTAssertEqual(reloaded.entries.first?.unit, .ml)
        XCTAssertEqual(reloaded.entries.first?.totalOz, 4)
    }
}
