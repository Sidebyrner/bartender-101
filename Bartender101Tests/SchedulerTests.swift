import XCTest
@testable import Bartender101

final class SchedulerTests: XCTestCase {
    func testFreshStateIsDueImmediately() {
        let state = ReviewState.fresh(drinkID: "negroni")
        XCTAssertTrue(state.isDue)
    }

    func testMissedResetsStreakAndShrinksEase() {
        let now = Date()
        var state = ReviewState.fresh(drinkID: "negroni", now: now)
        state = Scheduler.next(state: state, grade: .gotIt, now: now)
        state = Scheduler.next(state: state, grade: .gotIt, now: now)
        XCTAssertEqual(state.streak, 2)

        let missed = Scheduler.next(state: state, grade: .missed, now: now)
        XCTAssertEqual(missed.streak, 0)
        XCTAssertEqual(missed.lapses, 1)
        XCTAssertLessThan(missed.easeFactor, state.easeFactor)
        // A miss should resurface soon (within the hour), not tomorrow.
        XCTAssertLessThan(missed.dueDate.timeIntervalSince(now), 3600)
    }

    func testGotItGrowsIntervalAcrossReviews() {
        let now = Date()
        var state = ReviewState.fresh(drinkID: "margarita", now: now)
        var intervals: [Double] = []
        for _ in 0..<4 {
            state = Scheduler.next(state: state, grade: .gotIt, now: now)
            intervals.append(state.intervalDays)
        }
        // Each successive "got it" should push the interval out further,
        // matching the whole point of spaced repetition.
        for i in 1..<intervals.count {
            XCTAssertGreaterThan(intervals[i], intervals[i - 1], "interval should grow at step \(i)")
        }
    }

    func testInstantGrowsFasterThanGotIt() {
        let now = Date()
        let base = ReviewState.fresh(drinkID: "daiquiri", now: now)

        var gotItState = base
        var instantState = base
        for _ in 0..<3 {
            gotItState = Scheduler.next(state: gotItState, grade: .gotIt, now: now)
            instantState = Scheduler.next(state: instantState, grade: .instant, now: now)
        }

        XCTAssertGreaterThan(instantState.intervalDays, gotItState.intervalDays)
        XCTAssertGreaterThan(instantState.easeFactor, gotItState.easeFactor)
    }

    func testEaseFactorNeverDropsBelowMinimum() {
        let now = Date()
        var state = ReviewState.fresh(drinkID: "sazerac", now: now)
        for _ in 0..<20 {
            state = Scheduler.next(state: state, grade: .missed, now: now)
        }
        XCTAssertGreaterThanOrEqual(state.easeFactor, Scheduler.minEase)
    }

    func testEaseFactorNeverExceedsMaximum() {
        let now = Date()
        var state = ReviewState.fresh(drinkID: "mojito", now: now)
        for _ in 0..<20 {
            state = Scheduler.next(state: state, grade: .instant, now: now)
        }
        XCTAssertLessThanOrEqual(state.easeFactor, Scheduler.maxEase)
    }

    func testTotalReviewsIncrementsOnEveryGrade() {
        let now = Date()
        var state = ReviewState.fresh(drinkID: "mule", now: now)
        state = Scheduler.next(state: state, grade: .gotIt, now: now)
        state = Scheduler.next(state: state, grade: .missed, now: now)
        state = Scheduler.next(state: state, grade: .instant, now: now)
        XCTAssertEqual(state.totalReviews, 3)
    }

    func testDueDrinksIncludesNeverReviewedFirst() {
        let now = Date()
        let farFutureState = Scheduler.next(
            state: ReviewState.fresh(drinkID: "reviewed", now: now),
            grade: .instant,
            now: now
        )
        let states = ["reviewed": farFutureState]
        let drinks = [
            Drink.stub(id: "reviewed"),
            Drink.stub(id: "never-reviewed"),
        ]
        let due = Scheduler.dueDrinks(library: drinks, states: states, now: now)
        // The far-future card shouldn't be due; the never-reviewed one should.
        XCTAssertFalse(due.contains { $0.id == "reviewed" })
        XCTAssertTrue(due.contains { $0.id == "never-reviewed" })
    }
}
