import XCTest
@testable import GPXViewer

final class TracksStoreTests: XCTestCase {
    func testDateFromFilenameParsesDashedPrefix() {
        let date = TracksStore.dateFromFilename("2024-03-05 Morning Run")
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date ?? Date.distantPast)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 5)
    }

    func testDateFromFilenameParsesCompactPrefix() {
        let date = TracksStore.dateFromFilename("20240305 Morning Run")
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date ?? Date.distantPast)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 5)
    }

    func testDateFromFilenameReturnsNilWhenInvalid() {
        XCTAssertNil(TracksStore.dateFromFilename("2024-13-05 Morning Run"))
    }

    func testUniqueURLAddsNumericSuffixForCollisions() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let baseURL = tempDir.appendingPathComponent("track.gpx")
        let first = tempDir.appendingPathComponent("track-1.gpx")
        FileManager.default.createFile(atPath: baseURL.path, contents: Data())
        FileManager.default.createFile(atPath: first.path, contents: Data())

        let unique = TracksStore.uniqueURL(for: baseURL)

        XCTAssertEqual(unique.lastPathComponent, "track-2.gpx")
    }

    func testUniqueURLReturnsOriginalWhenAvailable() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let baseURL = tempDir.appendingPathComponent("track.gpx")

        let unique = TracksStore.uniqueURL(for: baseURL)

        XCTAssertEqual(unique, baseURL)
    }

    func testRenameFileRejectsEmptyName() {
        let store = TracksStore()
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = docsURL.appendingPathComponent("UnitTest-Empty.gpx")
        let file = GPXFile(
            id: fileURL,
            url: fileURL,
            displayName: "UnitTest-Empty",
            relativePath: "UnitTest-Empty.gpx",
            sortDate: nil,
            year: nil
        )

        let expectation = expectation(description: "Rename completion")
        store.renameFile(file, to: "   ") { result in
            if case .failure(let error) = result {
                XCTAssertEqual(error, .emptyName)
            } else {
                XCTFail("Expected rename to fail for empty name")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
    }

    func testRenameFileMovesFileAndPreservesStar() throws {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let originalURL = docsURL.appendingPathComponent("UnitTest-Rename-Original.gpx")
        let renamedURL = docsURL.appendingPathComponent("UnitTest-Rename-New.gpx")
        defer {
            try? FileManager.default.removeItem(at: originalURL)
            try? FileManager.default.removeItem(at: renamedURL)
        }
        FileManager.default.createFile(atPath: originalURL.path, contents: Data("test".utf8))

        let store = TracksStore()
        waitForTracks(store, toContain: originalURL)

        let file = GPXFile(
            id: originalURL,
            url: originalURL,
            displayName: "UnitTest-Rename-Original",
            relativePath: "UnitTest-Rename-Original.gpx",
            sortDate: nil,
            year: nil
        )

        store.toggleStar(for: file)
        XCTAssertTrue(store.starredRelativePaths.contains(file.relativePath))

        let expectation = expectation(description: "Rename completion")
        store.renameFile(file, to: "UnitTest-Rename-New") { result in
            switch result {
            case .success(let renamedFile):
                XCTAssertEqual(renamedFile.displayName, "UnitTest-Rename-New")
                XCTAssertFalse(FileManager.default.fileExists(atPath: originalURL.path))
                XCTAssertTrue(FileManager.default.fileExists(atPath: renamedFile.url.path))
                XCTAssertTrue(store.starredRelativePaths.contains("UnitTest-Rename-New.gpx"))
                XCTAssertFalse(store.starredRelativePaths.contains("UnitTest-Rename-Original.gpx"))
            case .failure(let error):
                XCTFail("Rename failed with error: \(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 4)
    }

    private func waitForTracks(_ store: TracksStore, toContain url: URL, timeout: TimeInterval = 2.0) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if store.files.contains(where: { $0.url == url }) {
                return
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
    }
}
