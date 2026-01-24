import XCTest

final class GPXViewerUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testTabNavigationAndSettingsControls() {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Library"].waitForExistence(timeout: 2))
        tabBar.buttons["Library"].tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 2))

        tabBar.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.switches["Offline Mode"].exists)
        XCTAssertTrue(app.switches["Distance Markers"].exists)
    }

    func testBaseMapSelectionFlow() {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Settings"].tap()
        guard let baseMapCell = waitForElement(with: "Default Base Map", in: app) else {
            XCTFail("Could not find Default Base Map cell")
            return
        }
        baseMapCell.tap()

        XCTAssertTrue(app.navigationBars["Base Map"].waitForExistence(timeout: 3))
        guard let openTopo = waitForElement(with: "OpenTopoMap", in: app, timeout: 1.0, scrolls: 6) else {
            XCTFail("Could not find OpenTopoMap option")
            return
        }
        openTopo.tap()
        app.navigationBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].exists)
    }

    private func waitForElement(with label: String, in app: XCUIApplication, timeout: TimeInterval = 1.5, scrolls: Int = 5) -> XCUIElement? {
        let candidates: [() -> XCUIElement] = [
            { app.buttons[label].firstMatch },
            { app.cells.staticTexts[label].firstMatch },
            { app.staticTexts[label].firstMatch }
        ]

        for _ in 0...scrolls {
            for candidate in candidates {
                let element = candidate()
                if element.waitForExistence(timeout: timeout) {
                    return element
                }
            }
            app.swipeUp()
        }
        return nil
    }
}
