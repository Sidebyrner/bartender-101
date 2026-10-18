import XCTest
import SwiftUI
@testable import Bartender101

/// `BarMetrics` turns the reader's text size into one scale factor that drives
/// every font, width and tap target on the recipe page. These pin the two
/// properties that are easy to break by accident: that nothing moves at the
/// default settings, and that growth never shrinks a tap target.
final class BarMetricsTests: XCTestCase {

    /// The baselines were authored to look like each mode's floor, so a reader
    /// who hasn't touched their text size sees exactly the sizes as written.
    func testScaleIsOneAtEachModesBaseline() {
        XCTAssertEqual(BarMetrics(isOn: true, typeSize: .large).scale, 1, accuracy: 0.001)
        XCTAssertEqual(BarMetrics(isOn: true, typeSize: .xxxLarge).scale, 1, accuracy: 0.001)
        XCTAssertEqual(BarMetrics(isOn: false, typeSize: .large).scale, 1, accuracy: 0.001)
    }

    /// Bartending Mode's floor means anything below `.xxxLarge` is clamped up
    /// to it, so a small system setting can't shrink the bar-side sizes.
    func testBartendingModeClampsSmallSizesUpToItsFloor() {
        let small = BarMetrics(isOn: true, typeSize: .xSmall)
        XCTAssertEqual(small.typeSize, .xxxLarge)
        XCTAssertEqual(small.scale, 1, accuracy: 0.001)
    }

    /// A larger text setting has to actually grow the sizes, or the whole
    /// exercise is decorative.
    func testLargerTextGrowsTheScale() {
        let baseline = BarMetrics(isOn: true, typeSize: .xxxLarge)
        let accessible = BarMetrics(isOn: true, typeSize: .accessibility3)
        XCTAssertGreaterThan(accessible.scale, baseline.scale)
        XCTAssertGreaterThan(accessible.amountColumnWidth, baseline.amountColumnWidth)
    }

    func testScaleNeverDecreasesAsTextGrows() {
        for isOn in [true, false] {
            var previous: CGFloat = 0
            for size in DynamicTypeSize.allCases.sorted() {
                let scale = BarMetrics(isOn: isOn, typeSize: size).scale
                XCTAssertGreaterThanOrEqual(
                    scale, previous,
                    "scale went backwards at \(size) with isOn: \(isOn)"
                )
                previous = scale
            }
        }
    }

    /// The HIG minimum, at every text size and in both modes. `scale` is
    /// floored at 1, so this can only break if a baseline drops below 44.
    func testTapTargetsNeverFallBelowFortyFour() {
        for isOn in [true, false] {
            for size in DynamicTypeSize.allCases {
                let metrics = BarMetrics(isOn: isOn, typeSize: size)
                XCTAssertGreaterThanOrEqual(
                    metrics.tapHeight, 44,
                    "tapHeight \(metrics.tapHeight) at \(size) with isOn: \(isOn)"
                )
            }
        }
    }

    /// Controls are damped relative to reading text, because a row of four
    /// buttons is bounded by the screen rather than by taste.
    func testControlsGrowMoreSlowlyThanReadingText() {
        let metrics = BarMetrics(isOn: true, typeSize: .accessibility5)
        XCTAssertLessThan(metrics.controlScale, metrics.scale)
        XCTAssertLessThanOrEqual(metrics.controlScale, 1.5)
        XCTAssertLessThanOrEqual(metrics.scale, 2.4)
    }

    /// The pour row only stacks where a fixed column would have forced the
    /// amount to shrink back down — that is, at accessibility sizes.
    func testPourRowStacksOnlyAtAccessibilitySizes() {
        for size in DynamicTypeSize.allCases {
            let metrics = BarMetrics(isOn: true, typeSize: size)
            XCTAssertEqual(
                metrics.stacksPourRow, size.isAccessibilitySize,
                "stacksPourRow disagreed with isAccessibilitySize at \(size)"
            )
        }
    }
}
