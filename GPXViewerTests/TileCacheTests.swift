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

    func testTrimRemovesOldestTilesWhenOverLimit() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let cache = TileCache(
            baseDirectory: tempDir,
            sizeLimit: 160,
            trimInterval: TimeInterval.greatestFiniteMagnitude
        )
        let provider = BaseMapProvider.openTopo
        let data = Data(repeating: 0x1, count: 80)

        let path1 = MKTileOverlayPath(x: 0, y: 0, z: 1, contentScaleFactor: 1)
        let path2 = MKTileOverlayPath(x: 1, y: 0, z: 1, contentScaleFactor: 1)
        let path3 = MKTileOverlayPath(x: 2, y: 0, z: 1, contentScaleFactor: 1)

        cache.store(data: data, provider: provider, path: path1)
        cache.store(data: data, provider: provider, path: path2)
        cache.store(data: data, provider: provider, path: path3)

        let url1 = cacheFileURL(baseDirectory: tempDir, provider: provider, path: path1)
        let url2 = cacheFileURL(baseDirectory: tempDir, provider: provider, path: path2)
        let url3 = cacheFileURL(baseDirectory: tempDir, provider: provider, path: path3)

        waitForFile(at: url1)
        waitForFile(at: url2)
        waitForFile(at: url3)

        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: url1.path)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 10)], ofItemAtPath: url2.path)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 20)], ofItemAtPath: url3.path)

        let trimExpectation = expectation(description: "trim finished")
        cache.trimNow {
            trimExpectation.fulfill()
        }
        wait(for: [trimExpectation], timeout: 2)

        XCTAssertFalse(FileManager.default.fileExists(atPath: url1.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url2.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url3.path))
    }

    private func cacheFileURL(baseDirectory: URL, provider: BaseMapProvider, path: MKTileOverlayPath) -> URL {
        let providerDir = baseDirectory.appendingPathComponent(provider.cacheKey, isDirectory: true)
        let zDir = providerDir.appendingPathComponent(String(path.z), isDirectory: true)
        let xDir = zDir.appendingPathComponent(String(path.x), isDirectory: true)
        let filename = "\(path.y).\(provider.tileFileExtension)"
        return xDir.appendingPathComponent(filename)
    }

    private func waitForFile(at url: URL, timeout: TimeInterval = 2) {
        let fileExpectation = expectation(description: "file exists")
        func poll() {
            if FileManager.default.fileExists(atPath: url.path) {
                fileExpectation.fulfill()
                return
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
                poll()
            }
        }
        poll()
        wait(for: [fileExpectation], timeout: timeout)
    }
}
