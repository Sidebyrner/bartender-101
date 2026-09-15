import Foundation

/// The grade given when reviewing a card, feeding the spaced-repetition
/// scheduler. Three grades on purpose — fewer choices mid-drill, and it
/// maps onto how recall actually feels: you either blanked, got there, or
/// it was instant.
enum ReviewGrade: String, Codable, CaseIterable {
    case missed
    case gotIt
    case instant
}

/// A single drink's spaced-repetition progress. One of these exists per
/// drink the user has reviewed at least once; drinks never reviewed simply
/// have no entry and count as due immediately.
///
/// Persisted as part of `ReviewStore`'s JSON file, and consumed only by
/// `Scheduler`'s pure functions — no SwiftUI or storage code depends on the
/// internal fields beyond reading `dueDate`.
struct ReviewState: Codable, Identifiable, Hashable {
    var id: String { drinkID }

    let drinkID: String
    /// Current spaced-repetition interval, in days.
    var intervalDays: Double
    /// SM-2 ease factor; higher means the interval grows faster on success.
    var easeFactor: Double
    /// Consecutive correct reviews since the last miss.
    var streak: Int
    /// Total times this card has been graded `.missed`.
    var lapses: Int
    /// Total times this card has been graded, of any grade — used to show
    /// accuracy in Stats (`(totalReviews - lapses) / totalReviews`).
    var totalReviews: Int
    var lastReviewedAt: Date?
    var dueDate: Date

    static func fresh(drinkID: String, now: Date = Date()) -> ReviewState {
        ReviewState(
            drinkID: drinkID,
            intervalDays: 0,
            easeFactor: 2.5,
            streak: 0,
            lapses: 0,
            totalReviews: 0,
            lastReviewedAt: nil,
            dueDate: now
        )
    }

    var isDue: Bool { dueDate <= Date() }
}
