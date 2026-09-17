import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import Bartender101

@MainActor
final class PhotoStoreTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("photos_\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    /// A solid-color JPEG of the given size, standing in for a camera shot.
    private func jpegData(width: Int, height: Int) throws -> Data {
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(red: 0.7, green: 0.4, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func pixelSize(at url: URL) throws -> (Int, Int) {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        return (props[kCGImagePropertyPixelWidth] as? Int ?? 0, props[kCGImagePropertyPixelHeight] as? Int ?? 0)
    }

    func testAddDownscalesWritesThumbnailAndReloads() async throws {
        let store = PhotoStore(directory: directory)
        let photo = await store.add(imageData: try jpegData(width: 4000, height: 3000), drinkID: "negroni", drinkName: "Negroni")
        let saved = try XCTUnwrap(photo)

        let (w, h) = try pixelSize(at: store.imageURL(for: saved))
        XCTAssertEqual(max(w, h), PhotoStore.maxPixelSize)
        XCTAssertEqual(w * 3, h * 4, "aspect ratio kept")
        let (tw, th) = try pixelSize(at: store.thumbnailURL(for: saved))
        XCTAssertEqual(max(tw, th), PhotoStore.thumbnailPixelSize)

        let reloaded = PhotoStore(directory: directory)
        XCTAssertEqual(reloaded.photos, [saved])
    }

    func testSmallImagesAreNotUpscaled() async throws {
        let store = PhotoStore(directory: directory)
        let savedResult = await store.add(imageData: try jpegData(width: 300, height: 200), drinkID: "d", drinkName: "D")
        let saved = try XCTUnwrap(savedResult)
        let (w, _) = try pixelSize(at: store.imageURL(for: saved))
        XCTAssertEqual(w, 300)
    }

    func testRejectsNonImageData() async {
        let store = PhotoStore(directory: directory)
        let result = await store.add(imageData: Data("not an image".utf8), drinkID: "d", drinkName: "D")
        XCTAssertNil(result)
        XCTAssertTrue(store.photos.isEmpty)
    }

    func testDeleteRemovesFiles() async throws {
        let store = PhotoStore(directory: directory)
        let savedResult = await store.add(imageData: try jpegData(width: 100, height: 100), drinkID: "d", drinkName: "D")
        let saved = try XCTUnwrap(savedResult)
        store.delete(id: saved.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.imageURL(for: saved).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.thumbnailURL(for: saved).path))
        XCTAssertTrue(PhotoStore(directory: directory).photos.isEmpty)
    }

    func testFilteringByDrinkNewestFirstAndShiftNight() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
        }
        let store = PhotoStore(directory: directory)
        let data = try jpegData(width: 50, height: 50)
        let eveningResult = await store.add(imageData: data, drinkID: "mojito", drinkName: "Mojito", takenAt: date(18, 22))
        let evening = try XCTUnwrap(eveningResult)
        let lateNightResult = await store.add(imageData: data, drinkID: "mojito", drinkName: "Mojito", takenAt: date(19, 1, 30))
        let lateNight = try XCTUnwrap(lateNightResult)
        let nextNightResult = await store.add(imageData: data, drinkID: "negroni", drinkName: "Negroni", takenAt: date(19, 21))
        let nextNight = try XCTUnwrap(nextNightResult)

        XCTAssertEqual(store.photos(for: "mojito").map(\.id), [lateNight.id, evening.id])
        XCTAssertEqual(Set(store.photos(onShiftNight: date(18, 0), calendar: calendar).map(\.id)), [evening.id, lateNight.id])
        XCTAssertEqual(store.photos(onShiftNight: date(19, 0), calendar: calendar).map(\.id), [nextNight.id])
    }
}
