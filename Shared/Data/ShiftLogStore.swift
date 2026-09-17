import Foundation

/// Persists every drink logged with "Made it" as a single JSON file in
/// Application Support — the same approach as `ReviewStore`, for the same
/// reasons: readable without a debugger, and a `[MadeDrink]` array maps
/// straight onto `localStorage` for a web build.
@MainActor
final class ShiftLogStore: ObservableObject {
    @Published private(set) var entries: [MadeDrink] = []

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        load()
    }

    private static func defaultFileURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("shift_log.json")
    }

    var nights: [ShiftLog.Night] { ShiftLog.nights(from: entries) }

    func tonight(now: Date = Date()) -> ShiftLog.Night? {
        ShiftLog.tonight(from: entries, now: now)
    }

    /// Logs one made drink with the scale settings on screen right now, and
    /// saves immediately so a force-quit mid-shift loses nothing.
    @discardableResult
    func record(drink: Drink, servings: Double, batchMode: Bool, unit: MeasurementUnit, now: Date = Date()) -> MadeDrink {
        let entry = MadeDrink(
            id: UUID(),
            drinkID: drink.id,
            drinkName: drink.name,
            madeAt: now,
            servings: servings,
            batchMode: batchMode,
            unit: unit,
            totalOz: ShiftLog.totalOz(for: drink, servings: servings, batchMode: batchMode)
        )
        entries.append(entry)
        save()
        return entry
    }

    func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func clearAll() {
        entries = []
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([MadeDrink].self, from: data) {
            entries = decoded
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
