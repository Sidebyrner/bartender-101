import Foundation

/// The display unit chosen in Settings. Stored as a raw value in
/// `UserDefaults` — see `SettingsView`.
enum MeasurementUnit: String, Codable, CaseIterable, Identifiable {
    case oz
    case ml

    var id: String { rawValue }
    var displayName: String { rawValue }
}

/// Formats an ounce amount for display, either as a bar-style fraction in
/// ounces or converted to milliliters.
///
/// Conversion uses the bar-standard 30 ml/oz (not the precise 29.57 ml),
/// rounded to the nearest 2.5 ml so the numbers match what's etched on a
/// real jigger (¾ oz -> 22.5 ml, 1½ oz -> 45 ml) instead of odd decimals.
enum Measure {
    static let mlPerOz: Double = 30

    static func milliliters(fromOz oz: Double) -> Double {
        let raw = oz * mlPerOz
        return (raw / 2.5).rounded() * 2.5
    }

    /// Renders an amount for the given unit, e.g. "¾ oz" or "22.5 ml".
    static func label(oz: Double, unit: MeasurementUnit) -> String {
        switch unit {
        case .oz:
            return "\(ozFraction(oz)) oz"
        case .ml:
            let ml = milliliters(fromOz: oz)
            if ml.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(ml)) ml"
            } else {
                return String(format: "%.1f ml", ml)
            }
        }
    }

    /// Renders `oz` as a mixed-number bar fraction rounded to the nearest
    /// eighth, e.g. 0.75 -> "¾", 1.5 -> "1½", 2 -> "2".
    static func ozFraction(_ oz: Double) -> String {
        let eighths = (oz * 8).rounded()
        let whole = Int(eighths) / 8
        let remainder = Int(eighths) % 8

        let fractionGlyphs: [Int: String] = [
            1: "⅛", 2: "¼", 3: "⅜", 4: "½", 5: "⅝", 6: "¾", 7: "⅞"
        ]

        switch (whole, remainder) {
        case (0, 0):
            return "0"
        case (_, 0):
            return "\(whole)"
        case (0, _):
            return fractionGlyphs[remainder] ?? String(format: "%.2f", oz)
        default:
            return "\(whole)\(fractionGlyphs[remainder] ?? "")"
        }
    }
}
