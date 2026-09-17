import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Keeps drink photos as JPEG files in Application Support, with a small
/// `photos.json` index — the same readable-on-disk approach as
/// `ShiftLogStore`. Each photo is saved downscaled (full images from a
/// phone camera are far bigger than a record needs) plus a thumbnail so
/// photo strips stay fast. Resizing uses ImageIO, so this layer has no
/// UIKit dependency.
@MainActor
final class PhotoStore: ObservableObject {
    /// Newest first.
    @Published private(set) var photos: [DrinkPhoto] = []

    nonisolated static let maxPixelSize = 2048
    nonisolated static let thumbnailPixelSize = 400

    let directory: URL
    private var indexURL: URL { directory.appendingPathComponent("photos.json") }

    init(directory: URL? = nil) {
        self.directory = directory ?? Self.defaultDirectory()
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        load()
    }

    private static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("DrinkPhotos", isDirectory: true)
    }

    func photos(for drinkID: String) -> [DrinkPhoto] {
        photos.filter { $0.drinkID == drinkID }
    }

    /// Photos taken during the shift night that `ShiftLog.shiftDay` maps to
    /// `night` — so a 1:30 AM photo belongs to the evening before.
    func photos(onShiftNight night: Date, calendar: Calendar = .current) -> [DrinkPhoto] {
        photos.filter { ShiftLog.shiftDay(for: $0.takenAt, calendar: calendar) == night }
    }

    func imageURL(for photo: DrinkPhoto) -> URL { directory.appendingPathComponent(photo.fileName) }
    func thumbnailURL(for photo: DrinkPhoto) -> URL { directory.appendingPathComponent(photo.thumbnailFileName) }

    /// Saves a photo of `drink` from raw image data (camera or library).
    /// Decoding, resizing, and writing happen off the main thread. Returns
    /// nil if the data isn't a readable image.
    @discardableResult
    func add(imageData: Data, drinkID: String, drinkName: String, takenAt: Date = Date()) async -> DrinkPhoto? {
        // Whole seconds: the index stores ISO 8601 dates, which drop fractions,
        // so a photo reloads exactly as it was saved.
        let wholeSeconds = Date(timeIntervalSince1970: takenAt.timeIntervalSince1970.rounded(.down))
        let photo = DrinkPhoto(id: UUID(), drinkID: drinkID, drinkName: drinkName, takenAt: wholeSeconds)
        let fullURL = imageURL(for: photo)
        let thumbURL = thumbnailURL(for: photo)
        let saved = await Task.detached(priority: .userInitiated) {
            Self.writeJPEG(from: imageData, maxPixelSize: Self.maxPixelSize, to: fullURL)
                && Self.writeJPEG(from: imageData, maxPixelSize: Self.thumbnailPixelSize, to: thumbURL)
        }.value
        guard saved else {
            try? FileManager.default.removeItem(at: fullURL)
            try? FileManager.default.removeItem(at: thumbURL)
            return nil
        }
        photos.insert(photo, at: 0)
        photos.sort { $0.takenAt > $1.takenAt }
        persist()
        return photo
    }

    func delete(id: UUID) {
        guard let photo = photos.first(where: { $0.id == id }) else { return }
        try? FileManager.default.removeItem(at: imageURL(for: photo))
        try? FileManager.default.removeItem(at: thumbnailURL(for: photo))
        photos.removeAll { $0.id == id }
        persist()
    }

    func deleteAll() {
        for photo in photos {
            try? FileManager.default.removeItem(at: imageURL(for: photo))
            try? FileManager.default.removeItem(at: thumbnailURL(for: photo))
        }
        photos = []
        persist()
    }

    /// Downscales image data so its longest side is at most `maxPixelSize`
    /// (never upscaling), honoring EXIF orientation, and writes a JPEG.
    nonisolated static func writeJPEG(from data: Data, maxPixelSize: Int, to url: URL) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { return false }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        return CGImageDestinationFinalize(destination)
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([DrinkPhoto].self, from: data) {
            // Drop index entries whose file has gone missing.
            photos = decoded
                .filter { FileManager.default.fileExists(atPath: imageURL(for: $0).path) }
                .sorted { $0.takenAt > $1.takenAt }
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(photos) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
