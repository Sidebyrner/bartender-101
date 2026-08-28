import Foundation

/// Fuzzy string matching for the reverse quiz's "type it" mode, so
/// `mojito`, `Mojito`, and `mohito` all count as correct. Pure functions,
/// no SwiftUI dependency — portable to the web build the same way as
/// `Scheduler`.
enum FuzzyMatch {
    /// Classic Levenshtein edit distance between two strings.
    static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = Swift.min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + cost
                )
            }
            previous = current
        }
        return previous[b.count]
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { $0.isLetter || $0.isNumber || $0 == " " }
    }

    /// Whether `input` is close enough to `target` to count as a correct
    /// answer, allowing for small typos that scale with the target's length
    /// (roughly one tolerated edit per six characters, minimum one).
    static func matches(input: String, target: String) -> Bool {
        let normInput = normalize(input)
        let normTarget = normalize(target)
        guard !normInput.isEmpty else { return false }
        if normInput == normTarget { return true }
        let threshold = max(1, normTarget.count / 6)
        return distance(normInput, normTarget) <= threshold
    }
}
