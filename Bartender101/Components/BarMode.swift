import SwiftUI
import UIKit

/// Sizes for Bartending Mode — big text and big tap targets for reading a
/// phone at arm's length behind the bar. Views read the mode from
/// `@AppStorage(SettingsKeys.bartendingMode)` and pull their sizes from here,
/// so "how big is big" is decided in one place.
///
/// The point sizes below are *baselines*, not fixed sizes. `Font.system(size:)`
/// doesn't scale with the reader's text size, so the growth is applied to the
/// numbers before they become fonts — and to the widths, heights and paddings
/// those fonts sit in, so nothing shrinks back to fit a column that stayed put.
///
/// Bartending Mode's numbers were authored to look like `.xxxLarge`, which is
/// also its floor, so at default settings the factor is exactly 1 in both
/// modes and nothing moves. Raising the system text size grows from there.
struct BarMetrics {
    let isOn: Bool

    /// The reader's text size, already clamped to `dynamicTypeRange` — the
    /// same clamp the screens apply, so what's measured here is what the
    /// screen actually renders at.
    let typeSize: DynamicTypeSize

    /// How far past this mode's baseline the reader's text size has moved.
    /// Never below 1: Bartending Mode and the 44pt tap minimum are a floor.
    let scale: CGFloat

    /// A damped `scale` for controls, whose width is bounded by the screen
    /// rather than by taste. A row of four buttons still has to fit.
    let controlScale: CGFloat

    /// Ceilings on the growth. Reading text may get very large; controls stop
    /// sooner so a row of buttons keeps its shape.
    private static let maxTextScale: CGFloat = 2.4
    private static let maxControlScale: CGFloat = 1.5

    init(isOn: Bool, typeSize: DynamicTypeSize = .large) {
        self.isOn = isOn
        let range = Self.range(isOn: isOn)
        let clamped = min(max(typeSize, range.lowerBound), range.upperBound)
        self.typeSize = clamped

        let baseline: DynamicTypeSize = isOn ? .xxxLarge : .large
        let raw = Self.bodyPointSize(clamped) / Self.bodyPointSize(baseline)
        self.scale = min(max(raw, 1), Self.maxTextScale)
        self.controlScale = min(max(raw, 1), Self.maxControlScale)
    }

    /// A baseline point size grown for the reader's text size.
    func scaled(_ points: CGFloat) -> CGFloat { (points * scale).rounded() }

    /// The same, damped — for tap targets and control widths.
    func scaledControl(_ points: CGFloat) -> CGFloat { (points * controlScale).rounded() }

    /// Minimum height for anything tappable.
    var tapHeight: CGFloat { scaledControl(isOn ? 56 : 44) }

    /// The ingredient amount — the single thing you glance down for.
    var amountFont: Font {
        .system(size: scaled(isOn ? 36 : 22), weight: .bold, design: .rounded).monospacedDigit()
    }

    /// Width of the amount column when the amount sits beside the ingredient.
    /// Grows with the font, so the text never shrinks back to fit the column.
    var amountColumnWidth: CGFloat { scaled(isOn ? 132 : 88) }

    /// At accessibility sizes no column is wide enough for both the amount and
    /// the ingredient, so the pour row stacks instead of squeezing.
    var stacksPourRow: Bool { typeSize.isAccessibilitySize }

    var ingredientFont: Font { isOn ? .system(size: scaled(26), weight: .semibold) : .title3 }
    var stepFont: Font { isOn ? .system(size: scaled(24), weight: .medium) : .body }
    var sectionLabelFont: Font { isOn ? .system(size: scaled(15), weight: .heavy) : .caption.weight(.bold) }
    var buttonFont: Font { isOn ? .system(size: scaledControl(22), weight: .bold) : .headline }

    /// The recipe page's drink name.
    var titleFont: Font { .system(size: scaled(isOn ? 40 : 32), weight: .bold, design: .serif) }

    /// The value on a Glass/Ice tile.
    var tileValueFont: Font {
        isOn ? .system(size: scaled(26), weight: .bold) : .title3.weight(.semibold)
    }

    /// The numbered circle on a pour row.
    var stepBadgeFont: Font { .system(size: scaled(isOn ? 18 : 14), weight: .bold, design: .rounded) }
    var stepBadgeSize: CGFloat { scaled(isOn ? 32 : 24) }

    /// Vertical padding inside a pour row.
    var rowPadding: CGFloat { scaled(isOn ? 12 : 8) }

    /// Text sizes for system-styled screens (Search). Bartending Mode sets a
    /// floor, never a ceiling, so a larger system text setting still wins.
    var dynamicTypeRange: ClosedRange<DynamicTypeSize> { Self.range(isOn: isOn) }

    private static func range(isOn: Bool) -> ClosedRange<DynamicTypeSize> {
        isOn ? .xxxLarge ... .accessibility5 : .xSmall ... .accessibility5
    }

    /// The system's body point size at a given text size — the ratio between
    /// two of these is how much everything else should grow.
    private static func bodyPointSize(_ size: DynamicTypeSize) -> CGFloat {
        UIFontMetrics(forTextStyle: .body).scaledValue(
            for: 17,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(size))
        )
    }
}
