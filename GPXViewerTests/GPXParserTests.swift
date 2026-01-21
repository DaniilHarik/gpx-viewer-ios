import Foundation
import XCTest
@testable import GPXViewer

final class GPXParserTests: XCTestCase {
    func testParseValidGPX() throws {
        let gpx = """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <gpx version=\"1.1\" creator=\"UnitTest\">
          <trk>
            <name>Test Track</name>
            <trkseg>
              <trkpt lat=\"59.0000\" lon=\"24.0000\">
                <ele>10</ele>
                <time>2020-01-01T10:00:00Z</time>
              </trkpt>
              <trkpt lat=\"59.0010\" lon=\"24.0010\">
                <ele>20</ele>
                <time>2020-01-01T10:10:00Z</time>
              </trkpt>
            </trkseg>
          </trk>
        </gpx>
        """
        let url = try writeTempFile(contents: gpx)

        let track = try GPXParser().parse(url: url)

        XCTAssertEqual(track.name, "Test Track")
        XCTAssertEqual(track.points.count, 2)
        XCTAssertFalse(track.bounds.isNull)
        XCTAssertGreaterThan(track.stats.distanceKm, 0)
    }

    func testParseNoPointsThrows() throws {
        let gpx = """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <gpx version=\"1.1\" creator=\"UnitTest\">
          <trk>
            <trkseg></trkseg>
          </trk>
        </gpx>
        """
        let url = try writeTempFile(contents: gpx)

        XCTAssertThrowsError(try GPXParser().parse(url: url)) { error in
            guard case GPXParserError.noPoints = error else {
                XCTFail("Expected GPXParserError.noPoints")
                return
            }
        }
    }

    func testParsesFractionalSecondsTimestamp() throws {
        let gpx = """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <gpx version=\"1.1\" creator=\"UnitTest\">
          <trk>
            <trkseg>
              <trkpt lat=\"59.0000\" lon=\"24.0000\">
                <time>2020-01-01T10:00:00.123Z</time>
              </trkpt>
            </trkseg>
          </trk>
        </gpx>
        """
        let url = try writeTempFile(contents: gpx)

        let track = try GPXParser().parse(url: url)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expected = formatter.date(from: "2020-01-01T10:00:00.123Z")
        XCTAssertEqual(track.points.first?.timestamp, expected)
    }

    private func writeTempFile(contents: String) throws -> URL {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("gpx")
        guard let data = contents.data(using: .utf8) else {
            throw NSError(domain: "GPXViewerTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode GPX contents."])
        }
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
