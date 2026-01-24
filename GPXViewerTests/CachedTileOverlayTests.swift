import MapKit
import XCTest
@testable import GPXViewer

final class CachedTileOverlayTests: XCTestCase {
    func testOfflineModeReturnsEmptyTileWithoutCaching() {
        let cache = TileCache.shared
        let clearExpectation = expectation(description: "cache cleared")
        cache.clearAll {
            clearExpectation.fulfill()
        }
        wait(for: [clearExpectation], timeout: 2)

        let overlay = CachedTileOverlay(provider: .openTopo, offlineMode: true)
        let path = MKTileOverlayPath(x: 0, y: 0, z: 1, contentScaleFactor: 1)

        let loadExpectation = expectation(description: "tile loaded")
        overlay.loadTile(at: path) { data, error in
            XCTAssertNotNil(data)
            XCTAssertNil(error)
            XCTAssertFalse(data?.isEmpty ?? true)
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 2)

        XCTAssertNil(cache.load(provider: .openTopo, path: path))
    }

    func testZoomAboveMaxReturnsEmptyTile() {
        let overlay = CachedTileOverlay(provider: .openTopo, offlineMode: false)
        let path = MKTileOverlayPath(x: 0, y: 0, z: BaseMapProvider.openTopo.maxZoom + 1, contentScaleFactor: 1)

        let loadExpectation = expectation(description: "tile loaded")
        overlay.loadTile(at: path) { data, error in
            XCTAssertNotNil(data)
            XCTAssertNil(error)
            XCTAssertFalse(data?.isEmpty ?? true)
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 2)
    }
}
