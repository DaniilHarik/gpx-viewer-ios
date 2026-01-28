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
        XCTAssertTrue(tabBar.buttons["Tracks"].waitForExistence(timeout: 2))
        tabBar.buttons["Tracks"].tap()
        XCTAssertTrue(app.navigationBars["Tracks"].waitForExistence(timeout: 2))

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

    func testRenameTrackFromTracks() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing")
        app.launch()

        app.tabBars.buttons["Tracks"].tap()
        let originalName = "UI Test Track"
        let renamedName = "UI Test Track Renamed"

        let originalCell = app.staticTexts[originalName].firstMatch
        XCTAssertTrue(originalCell.waitForExistence(timeout: 4))
        originalCell.press(forDuration: 1.0)

        let renameButton = app.buttons["Rename"].firstMatch
        XCTAssertTrue(renameButton.waitForExistence(timeout: 2))
        renameButton.tap()

        let alert = app.alerts["Rename Track"].firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 2))

        let textField = alert.textFields["Track name"].firstMatch
        XCTAssertTrue(textField.exists)
        textField.tap()
        textField.clearText()
        textField.typeText(renamedName)
        alert.buttons["Rename"].tap()

        let renamedCell = app.staticTexts[renamedName].firstMatch
        XCTAssertTrue(renamedCell.waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts[originalName].exists)
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

private extension XCUIElement {
    func clearText() {
        guard let stringValue = value as? String else { return }
        tap()
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        typeText(deleteString)
    }
}
