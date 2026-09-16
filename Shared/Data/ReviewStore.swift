import Foundation

/// Persists per-drink spaced-repetition progress as a single Codable JSON
/// file in Application Support — not SwiftData. That keeps the persistence
/// layer something a human can read and reason about without a debugger
/// (this project is written without ever compiling on a Mac, so anything
/// that can fail silently at runtime is avoided), and the same
/// `[String: ReviewState]` shape maps directly onto a `localStorage` blob
/// for the future web build.
@MainActor
final class ReviewStore: ObservableObject {
    @Published private(set) var states: [String: ReviewState] = [:]

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        load()
    }

    private static func defaultFileURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("review_progress.json")
    }

    func state(for drinkID: String) -> ReviewState {
        states[drinkID] ?? ReviewState.fresh(drinkID: drinkID)
    }

    /// Grades a card and persists the resulting state immediately, so
    /// progress survives a force-quit mid-session.
    func grade(drinkID: String, grade: ReviewGrade, now: Date = Date()) {
        let current = state(for: drinkID)
        states[drinkID] = Scheduler.next(state: current, grade: grade, now: now)
        save()
    }

    func dueDrinks(from library: [Drink], now: Date = Date()) -> [Drink] {
        Scheduler.dueDrinks(library: library, states: states, now: now)
    }

    /// Drinks reviewed at least once with more misses than clean reviews —
    /// surfaced in Stats as what to focus on.
    func weakDrinks(from library: [Drink], limit: Int = 10) -> [Drink] {
        let weak = states.values
            .filter { $0.lapses > 0 }
            .sorted { $0.lapses > $1.lapses }
            .prefix(limit)
        let byID = Dictionary(uniqueKeysWithValues: library.map { ($0.id, $0) })
        return weak.compactMap { byID[$0.drinkID] }
    }

    func resetProgress() {
        states = [:]
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([String: ReviewState].self, from: data) {
            states = decoded
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(states) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
