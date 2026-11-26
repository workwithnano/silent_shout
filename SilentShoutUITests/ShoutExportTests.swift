import XCTest

/// The "Export Shout" sheet (phase 5). Saving uses the app's fake photo library
/// (`-UITestPhotoSaver saved|denied`): the real one would show a device-wide permission prompt
/// and add pictures to the shared simulator's library, which other apps' test runs share.
final class ShoutExportTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func shout(_ app: XCUIApplication, message: String) -> ShoutScreen {
        app.launch()
        let editing = EditingScreen(app: app)
        editing.open()
        editing.textField.typeText(message)
        XCTAssertTrue(editing.waitForPreview(message))
        editing.textField.typeText("\n")
        let shout = ShoutScreen(app: app)
        XCTAssertTrue(shout.waitForShout(message))
        return shout
    }

    /// The export button comes and goes with the toolbar; the sheet has the original title and
    /// actions (no iMessage in the simulator, which cannot send); Cancel goes back to the shout
    /// with the toolbar as it was.
    @MainActor
    func testExportSheetShowsTheOriginalChoices() {
        XCUIDevice.shared.orientation = .portrait
        let shout = shout(.optionsApp(reset: true), message: "Go team")
        XCTAssertFalse(shout.share.exists, "no export button while the toolbar is hidden")
        shout.showToolbar()
        XCTAssertTrue(shout.share.exists)
        XCTAssertEqual(shout.share.label, "Export Shout")

        shout.press(shout.share)
        XCTAssertTrue(shout.waitForExportSheet())
        XCTAssertTrue(shout.saveToCameraRoll.exists)
        XCTAssertTrue(shout.cancel.exists)
        XCTAssertFalse(shout.sendInMessages.exists, "the simulator cannot send messages, so the choice is hidden")

        shout.press(shout.cancel)
        XCTAssertTrue(shout.waitForExportSheet(visible: false))
        XCTAssertTrue(shout.text.exists, "back on the shout")
        XCTAssertTrue(shout.waitForToolbar(visible: true), "Cancel did not toggle the toolbar")
    }

    /// A tap outside the sheet closes it without reaching the shout's tap-to-toggle underneath.
    @MainActor
    func testTapOutsideTheSheetDoesNotToggleTheToolbar() {
        XCUIDevice.shared.orientation = .portrait
        let shout = shout(.optionsApp(reset: true), message: "Hello")
        shout.showToolbar()
        shout.press(shout.share)
        XCTAssertTrue(shout.waitForExportSheet())
        // Lower left of the landscape screen, away from the sheet near the export button.
        let window = shout.app.windows.firstMatch
        window.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: window.frame.width * 0.2, dy: window.frame.height * 0.8))
            .tap()
        XCTAssertTrue(shout.waitForExportSheet(visible: false))
        XCTAssertTrue(shout.waitForToolbar(visible: true), "the toolbar is still showing")
        XCTAssertTrue(shout.text.exists)
    }

    /// Save to Camera Roll: a brief confirmation, and the shout stays.
    @MainActor
    func testSaveToCameraRollConfirms() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.optionsApp(reset: true)
        app.launchArguments += ["-UITestPhotoSaver", "saved"]
        let shout = shout(app, message: "Saved?")
        shout.showToolbar()
        shout.press(shout.share)
        XCTAssertTrue(shout.waitForExportSheet())
        shout.press(shout.saveToCameraRoll)
        XCTAssertTrue(shout.savedNote.waitForExistence(timeout: 5), "Saved to Photos shows")
        XCTAssertEqual(shout.savedNote.label, "Saved to Photos")
        XCTAssertTrue(shout.text.exists)
        XCTAssertTrue(shout.waitForToolbar(visible: true))
    }

    /// Refused access: a short alert with a way to Settings; OK returns to the shout.
    @MainActor
    func testSaveDeniedOffersSettings() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.optionsApp(reset: true)
        app.launchArguments += ["-UITestPhotoSaver", "denied"]
        let shout = shout(app, message: "No access")
        shout.showToolbar()
        shout.press(shout.share)
        XCTAssertTrue(shout.waitForExportSheet())
        shout.press(shout.saveToCameraRoll)

        let alert = app.alerts["Can't Save to Photos"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.buttons["Settings"].exists)
        XCTAssertTrue(alert.buttons["OK"].exists)
        shout.press(alert.buttons["OK"])
        XCTAssertTrue(shout.waitUntilGone(alert))
        XCTAssertTrue(shout.text.exists)
        XCTAssertTrue(shout.waitForToolbar(visible: true))
        XCTAssertFalse(shout.savedNote.exists)
    }

    /// Turning the phone upright while the sheet is up keeps the shout; closing the sheet then
    /// leaves it, as turning upright would have (SPEC.md section 1). Nothing on screen changes
    /// when the phone turns under the sheet, so the test waits for the app's own report that it
    /// has received the turn (`-UITestShoutState`) before checking that the shout stayed.
    @MainActor
    func testPortraitWhileSheetIsUpWaitsForTheSheet() {
        addTeardownBlock { @MainActor in XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.optionsApp(reset: true)
        app.launchArguments.append("-UITestShoutState")
        app.launch()
        let editing = EditingScreen(app: app)
        editing.open()
        editing.textField.typeText("Turn")
        XCTAssertTrue(editing.waitForPreview("Turn"))
        XCUIDevice.shared.orientation = .landscapeLeft
        let shout = ShoutScreen(app: app)
        XCTAssertTrue(shout.waitForShout("Turn"))
        XCTAssertEqual(shout.stateAfterTurning(to: "landscapeLeft"), "landscapeLeft shouting")
        shout.showToolbar()
        shout.press(shout.share)
        XCTAssertTrue(shout.waitForExportSheet())

        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(shout.stateAfterTurning(to: "portrait"), "portrait shouting",
                       "the app saw the phone turn upright and kept the shout while the sheet is up")
        XCTAssertTrue(shout.text.exists)
        XCTAssertTrue(shout.cancel.exists)

        shout.press(shout.cancel)
        XCTAssertTrue(shout.waitUntilGone(), "closing the sheet upright leaves the shout")
        XCTAssertTrue(editing.waitForFocus())
    }

    /// Pictures for docs/rewrite/screenshots/: the toolbar with the export button, and the sheet.
    @MainActor
    func testExportScreenshots() {
        addTeardownBlock { @MainActor in XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.optionsApp(font: 1, texture: 0, lettering: 0)
        app.launch()
        let editing = EditingScreen(app: app)
        editing.open()
        editing.textField.typeText("Happy birthday Sam!")
        XCTAssertTrue(editing.waitForPreview("Happy birthday Sam!"))
        XCUIDevice.shared.orientation = .landscapeLeft
        let shout = ShoutScreen(app: app)
        XCTAssertTrue(shout.waitForShout("Happy birthday Sam!"))
        shout.showToolbar()
        attach("shout-export-button")
        shout.press(shout.share)
        XCTAssertTrue(shout.waitForExportSheet())
        attach("shout-export-sheet")
    }

    @MainActor
    private func attach(_ name: String) {
        sleep(1) // pictures only (as phase 4's screenshots): let the fade settle; no assertion depends on it
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
