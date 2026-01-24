import XCTest
@testable import GPXViewer

final class LibraryStoreTests: XCTestCase {
    func testDateFromFilenameParsesDashedPrefix() {
        let date = LibraryStore.dateFromFilename("2024-03-05 Morning Run")
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date ?? Date.distantPast)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 5)
    }

    func testDateFromFilenameParsesCompactPrefix() {
        let date = LibraryStore.dateFromFilename("20240305 Morning Run")
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date ?? Date.distantPast)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 5)
    }

    func testDateFromFilenameReturnsNilWhenInvalid() {
        XCTAssertNil(LibraryStore.dateFromFilename("2024-13-05 Morning Run"))
    }

    func testUniqueURLAddsNumericSuffixForCollisions() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let baseURL = tempDir.appendingPathComponent("track.gpx")
        let first = tempDir.appendingPathComponent("track-1.gpx")
        FileManager.default.createFile(atPath: baseURL.path, contents: Data())
        FileManager.default.createFile(atPath: first.path, contents: Data())

        let unique = LibraryStore.uniqueURL(for: baseURL)

        XCTAssertEqual(unique.lastPathComponent, "track-2.gpx")
    }

    func testUniqueURLReturnsOriginalWhenAvailable() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let baseURL = tempDir.appendingPathComponent("track.gpx")

        let unique = LibraryStore.uniqueURL(for: baseURL)

        XCTAssertEqual(unique, baseURL)
    }
}
