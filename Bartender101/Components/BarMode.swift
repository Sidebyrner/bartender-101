import SwiftUI

/// Sizes for Bartending Mode — big text and big tap targets for reading a
/// phone at arm's length behind the bar. Views read the mode from
/// `@AppStorage(SettingsKeys.bartendingMode)` and pull their sizes from here,
/// so "how big is big" is decided in one place.
struct BarMetrics {
    let isOn: Bool

    /// Minimum height for anything tappable.
    var tapHeight: CGFloat { isOn ? 56 : 44 }

    /// The ingredient amount — the single thing you glance down for.
    var amountFont: Font { .system(size: isOn ? 36 : 22, weight: .bold, design: .rounded).monospacedDigit() }
    var amountColumnWidth: CGFloat { isOn ? 132 : 88 }

    var ingredientFont: Font { isOn ? .system(size: 26, weight: .semibold) : .title3 }
    var stepFont: Font { isOn ? .system(size: 24, weight: .medium) : .body }
    var sectionLabelFont: Font { isOn ? .system(size: 15, weight: .heavy) : .caption.weight(.bold) }
    var buttonFont: Font { isOn ? .system(size: 22, weight: .bold) : .headline }

    /// Text sizes for system-styled screens (Search). Bartending Mode sets a
    /// floor, never a ceiling, so a larger system text setting still wins.
    var dynamicTypeRange: ClosedRange<DynamicTypeSize> {
        isOn ? .xxxLarge ... .accessibility5 : .xSmall ... .accessibility5
    }
}
