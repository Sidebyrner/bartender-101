import Foundation

/// Spaced-repetition scheduling, SM-2 style but simplified to the three
/// grades `ReviewGrade` offers instead of SM-2's usual 0-5 scale.
///
/// Deliberately pure functions with no dependency on SwiftUI, `Date()`
/// defaults aside, or on `ReviewStore`. That keeps the interval math
/// unit-testable (`SchedulerTests.swift`) and gives the future web build a
/// direct line to port: this logic translates to TypeScript almost
/// statement-for-statement.
enum Scheduler {
    static let minEase = 1.3
    static let maxEase = 3.0

    /// Computes the next `ReviewState` after grading a card.
    static func next(state: ReviewState, grade: ReviewGrade, now: Date = Date()) -> ReviewState {
        var s = state
        s.lastReviewedAt = now
        s.totalReviews += 1

        switch grade {
        case .missed:
            // A miss resets the streak and shrinks the ease factor so future
            // intervals grow more cautiously, but doesn't erase everything —
            // it resurfaces soon (10 minutes) rather than tomorrow, so it
            // can be caught again within the same study session.
            s.lapses += 1
            s.streak = 0
            s.easeFactor = max(minEase, s.easeFactor - 0.2)
            s.intervalDays = 10.0 / (24 * 60)

        case .gotIt:
            s.streak += 1
            switch s.streak {
            case 1: s.intervalDays = 1
            case 2: s.intervalDays = 3
            default: s.intervalDays = max(1, s.intervalDays * s.easeFactor)
            }

        case .instant:
            // Recalled instantly: stretch the interval more aggressively
            // and nudge ease up so this card keeps growing faster than one
            // that's merely "got it".
            s.streak += 1
            s.easeFactor = min(maxEase, s.easeFactor + 0.15)
            switch s.streak {
            case 1: s.intervalDays = 2
            case 2: s.intervalDays = 5
            default: s.intervalDays = max(1, s.intervalDays * s.easeFactor * 1.3)
            }
        }

        s.dueDate = now.addingTimeInterval(s.intervalDays * 24 * 60 * 60)
        return s
    }

    /// All drinks currently due for review: either never reviewed, or past
    /// their `dueDate`. Never-reviewed drinks sort first so a fresh deck
    /// gets introduced before older cards are re-drilled.
    static func dueDrinks(library: [Drink], states: [String: ReviewState], now: Date = Date()) -> [Drink] {
        library
            .filter { drink in
                guard let state = states[drink.id] else { return true }
                return state.dueDate <= now
            }
            .sorted { a, b in
                let aReviewed = states[a.id] != nil
                let bReviewed = states[b.id] != nil
                if aReviewed != bReviewed { return !aReviewed && bReviewed }
                let aDue = states[a.id]?.dueDate ?? .distantPast
                let bDue = states[b.id]?.dueDate ?? .distantPast
                return aDue < bDue
            }
    }
}
