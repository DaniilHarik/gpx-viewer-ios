import Foundation
import MapKit
import XCTest
@testable import GPXViewer

final class TileCacheTests: XCTestCase {
    func testStoreAndLoadTile() {
        let cache = TileCache.shared
        let clearExpectation = expectation(description: "cache cleared")
        cache.clearAll {
            clearExpectation.fulfill()
        }
        wait(for: [clearExpectation], timeout: 2)

        let data = Data("tile".utf8)
        let path = MKTileOverlayPath(x: 1, y: 2, z: 3, contentScaleFactor: 1)
        cache.store(data: data, provider: .openTopo, path: path)

        guard let loaded = cache.load(provider: .openTopo, path: path) else {
            XCTFail("Expected cached data")
            return
        }
        XCTAssertEqual(loaded, data)

        let clearAfterExpectation = expectation(description: "cache cleared after")
        cache.clearAll {
            clearAfterExpectation.fulfill()
        }
        wait(for: [clearAfterExpectation], timeout: 2)
    }
}
