import Foundation

/// Persists house drinks made in the Build tab as a single JSON file in
/// Application Support — the same approach as `ShiftLogStore` and
/// `ReviewStore`: readable without a debugger, and a `[CustomDrink]` array
/// maps straight onto `localStorage` for a web build.
@MainActor
final class CustomDrinkStore: ObservableObject {
    @Published private(set) var drinks: [CustomDrink] = []

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        load()
    }

    private static func defaultFileURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("custom_drinks.json")
    }

    func drink(id: String) -> CustomDrink? { drinks.first { $0.id == id } }

    /// Drinks in one board column, most recently touched first.
    func drinks(in stage: TestStage) -> [CustomDrink] {
        drinks.filter { $0.stage == stage }.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Inserts or replaces by id, stamping `updatedAt`, and saves immediately
    /// so a force-quit mid-shift loses nothing.
    func save(_ drink: CustomDrink, now: Date = Date()) {
        var drink = drink
        drink.updatedAt = now
        if let index = drinks.firstIndex(where: { $0.id == drink.id }) {
            drinks[index] = drink
        } else {
            drinks.append(drink)
        }
        persist()
    }

    func move(id: String, to stage: TestStage, now: Date = Date()) {
        guard var drink = drink(id: id), drink.stage != stage else { return }
        drink.stage = stage
        save(drink, now: now)
    }

    func addTasting(id: String, note: TastingNote, now: Date = Date()) {
        guard var drink = drink(id: id) else { return }
        drink.tastings.append(note)
        save(drink, now: now)
    }

    func removeTasting(id: String, noteID: UUID, now: Date = Date()) {
        guard var drink = drink(id: id) else { return }
        drink.tastings.removeAll { $0.id == noteID }
        save(drink, now: now)
    }

    /// Copies a drink as a fresh idea to try a variation without losing the
    /// original spec. Tasting notes stay with the original.
    @discardableResult
    func duplicate(id: String, now: Date = Date()) -> CustomDrink? {
        guard let original = drink(id: id) else { return nil }
        let copy = CustomDrink(
            name: original.displayName + " v2",
            family: original.family,
            glass: original.glass,
            ice: original.ice,
            method: original.method,
            ingredients: original.ingredients,
            garnish: original.garnish,
            notes: original.notes,
            stage: .testing,
            labels: original.labels,
            basedOnDrinkID: original.basedOnDrinkID,
            createdAt: now
        )
        save(copy, now: now)
        return copy
    }

    func delete(id: String) {
        drinks.removeAll { $0.id == id }
        persist()
    }

    func deleteAll() {
        drinks = []
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([CustomDrink].self, from: data) {
            drinks = decoded
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(drinks) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
