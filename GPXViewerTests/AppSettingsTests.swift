import XCTest
@testable import GPXViewer

final class AppSettingsTests: XCTestCase {
    private let keys = [
        "theme",
        "offlineMode",
        "baseMap",
        "distanceMarkersEnabled"
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
    }

    func testPersistsChangesAcrossInstances() {
        let settings = AppSettings()
        settings.theme = .dark
        settings.offlineMode = true
        settings.baseMap = .openTopo
        settings.distanceMarkersEnabled = false

        let reloaded = AppSettings()

        XCTAssertEqual(reloaded.theme, .dark)
        XCTAssertEqual(reloaded.offlineMode, true)
        XCTAssertEqual(reloaded.baseMap, .openTopo)
        XCTAssertEqual(reloaded.distanceMarkersEnabled, false)
    }

    func testResetRestoresDefaults() {
        let settings = AppSettings()
        settings.theme = .dark
        settings.offlineMode = true
        settings.baseMap = .openTopo
        settings.distanceMarkersEnabled = false

        settings.reset()

        XCTAssertEqual(settings.theme, .light)
        XCTAssertEqual(settings.offlineMode, false)
        XCTAssertEqual(settings.baseMap, .maaKaart)
        XCTAssertEqual(settings.distanceMarkersEnabled, true)
    }

    private func clearDefaults() {
        let defaults = UserDefaults.standard
        for key in keys {
            defaults.removeObject(forKey: key)
        }
    }
}
