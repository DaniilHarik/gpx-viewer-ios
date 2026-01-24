import XCTest
@testable import GPXViewer

final class AppSettingsTests: XCTestCase {
    private let keys = [
        "theme",
        "offlineMode",
        "baseMap",
        "baseMapId",
        "tileProviders",
        "distanceMarkersEnabled",
        "distanceMarkerInterval"
    ]

    override func setUp() {
        super.setUp()
        clearDefaults()
    }

    override func tearDown() {
        clearDefaults()
        super.tearDown()
    }

    func testDefaultsWhenNoStoredValues() {
        let settings = AppSettings()

        XCTAssertEqual(settings.theme, .light)
        XCTAssertEqual(settings.offlineMode, false)
        XCTAssertEqual(settings.baseMap, .maaKaart)
        XCTAssertEqual(settings.distanceMarkersEnabled, true)
        XCTAssertEqual(settings.distanceMarkerInterval, .one)
    }

    func testPersistsChangesAcrossInstances() {
        let settings = AppSettings()
        settings.theme = .dark
        settings.offlineMode = true
        settings.baseMap = .openTopo
        settings.distanceMarkersEnabled = false
        settings.distanceMarkerInterval = .ten

        let reloaded = AppSettings()

        XCTAssertEqual(reloaded.theme, .dark)
        XCTAssertEqual(reloaded.offlineMode, true)
        XCTAssertEqual(reloaded.baseMap, .openTopo)
        XCTAssertEqual(reloaded.distanceMarkersEnabled, false)
        XCTAssertEqual(reloaded.distanceMarkerInterval, .ten)
    }

    func testResetRestoresDefaults() {
        let settings = AppSettings()
        settings.theme = .dark
        settings.offlineMode = true
        settings.baseMap = .openTopo
        settings.distanceMarkersEnabled = false
        settings.distanceMarkerInterval = .five

        settings.reset()

        XCTAssertEqual(settings.theme, .light)
        XCTAssertEqual(settings.offlineMode, false)
        XCTAssertEqual(settings.baseMap, .maaKaart)
        XCTAssertEqual(settings.distanceMarkersEnabled, true)
        XCTAssertEqual(settings.distanceMarkerInterval, .one)
    }

    private func clearDefaults() {
        let defaults = UserDefaults.standard
        for key in keys {
            defaults.removeObject(forKey: key)
        }
    }
}
