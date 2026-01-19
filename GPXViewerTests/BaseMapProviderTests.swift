import XCTest
@testable import GPXViewer

final class BaseMapProviderTests: XCTestCase {
    func testOpenTopoURLUsesXYZ() {
        let url = BaseMapProvider.openTopo.tileURL(z: 2, x: 3, y: 4)
        XCTAssertEqual(url.absoluteString, "https://a.tile.opentopomap.org/2/3/4.png")
    }

    func testMaaKaartURLInvertsTMSYAxis() {
        let url = BaseMapProvider.maaKaart.tileURL(z: 1, x: 2, y: 0)
        XCTAssertEqual(url.absoluteString, "https://tiles.maaamet.ee/tm/tms/1.0.0/kaart@GMC/1/2/1.png&ASUTUS=MAAAMET&KESKKOND=LIVE&IS=TMSNAIDE")
    }

    func testMaaFotoUsesJpegExtension() {
        XCTAssertEqual(BaseMapProvider.maaFoto.tileFileExtension, "jpg")
    }
}
