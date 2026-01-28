import XCTest
@testable import GPXViewer

final class TracksRowFormatterTests: XCTestCase {
    func testDatePrefixExtractsValidPrefix() {
        XCTAssertEqual(TracksRowFormatter.datePrefix(from: "2024-03-05 Morning Run"), "2024-03-05")
    }

    func testDatePrefixRejectsInvalidPrefix() {
        XCTAssertNil(TracksRowFormatter.datePrefix(from: "2024-13-05 Morning Run"))
    }

    func testDisplayTitleStripsPrefixAndSeparators() {
        XCTAssertEqual(TracksRowFormatter.displayTitle(for: "2024-03-05 - Morning Run"), "Morning Run")
        XCTAssertEqual(TracksRowFormatter.displayTitle(for: "2024-03-05_Morning Run"), "Morning Run")
    }

    func testDisplayTitleFallsBackWhenOnlyPrefix() {
        XCTAssertEqual(TracksRowFormatter.displayTitle(for: "2024-03-05"), "2024-03-05")
    }

    func testSubtitleUsesRelativePathWhenNoPrefix() {
        let file = makeFile(displayName: "Morning Run", relativePath: "Trips/Morning Run.gpx")
        XCTAssertEqual(TracksRowFormatter.subtitle(for: file), "Trips/Morning Run.gpx")
    }

    private func makeFile(displayName: String, relativePath: String) -> GPXFile {
        GPXFile(
            id: URL(fileURLWithPath: "/tmp/\(displayName).gpx"),
            url: URL(fileURLWithPath: "/tmp/\(displayName).gpx"),
            displayName: displayName,
            relativePath: relativePath,
            sortDate: nil,
            year: nil
        )
    }
}
