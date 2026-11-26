import XCTest

final class EditingScreenTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// What is typed appears in the preview as it is typed; the clear button empties both.
    @MainActor
    func testTypingShowsTextInPreview() {
        let app = XCUIApplication.optionsApp(reset: true)
        app.launch()
        let editing = EditingScreen(app: app)
        editing.open()
        XCTAssertTrue(editing.waitForPreview(""), "fresh settings: nothing to preview")

        editing.textField.typeText("Hello")
        XCTAssertTrue(editing.waitForPreview("Hello"))
        editing.textField.typeText(" there")
        XCTAssertTrue(editing.waitForPreview("Hello there"))

        XCTAssertTrue(editing.clearButton.exists, "clear button while editing")
        editing.clearButton.tap()
        XCTAssertTrue(editing.waitForField(""))
        XCTAssertTrue(editing.waitForPreview(""))
        XCTAssertTrue(editing.waitForFocus(), "clearing keeps the keyboard up")
    }

    /// The back (toggle) button saves the text and returns to Options without shouting.
    @MainActor
    func testToggleReturnsToOptionsAndKeepsText() {
        let app = XCUIApplication.optionsApp(reset: true)
        app.launch()
        let editing = EditingScreen(app: app)
        editing.open()

        editing.textField.typeText("Back soon")
        XCTAssertTrue(editing.waitForPreview("Back soon"))
        editing.backButton.tap()

        let next = app.buttons["options.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertTrue(editing.waitUntilGone(editing.textField))
        XCTAssertTrue(next.isHittable)
        XCTAssertFalse(ShoutScreen(app: app).text.exists, "the toggle never starts the shout")

        next.tap()
        XCTAssertTrue(editing.waitForField("Back soon"))
        XCTAssertTrue(editing.waitForPreview("Back soon"))
        XCTAssertTrue(editing.waitForFocus())
    }

    /// Text saved on leaving Editing (toggle) or on going to the background survives a relaunch.
    @MainActor
    func testTextSurvivesRelaunch() {
        let app = XCUIApplication.optionsApp(reset: true)
        app.launch()
        var editing = EditingScreen(app: app)
        editing.open()
        editing.textField.typeText("Lunch at noon")
        XCTAssertTrue(editing.waitForPreview("Lunch at noon"))
        editing.backButton.tap()
        XCTAssertTrue(app.buttons["options.next"].waitForExistence(timeout: 5))
        app.terminate()

        let second = XCUIApplication.optionsApp(reset: false)
        second.launch()
        editing = EditingScreen(app: second)
        editing.open()
        XCTAssertTrue(editing.waitForField("Lunch at noon"))
        XCTAssertTrue(editing.waitForPreview("Lunch at noon"))

        // Leaving the app from Editing saves too.
        editing.textField.typeText(" today")
        XCTAssertTrue(editing.waitForPreview("Lunch at noon today"))
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(second.wait(for: .runningBackgroundSuspended, timeout: 10) || second.state == .runningBackground)
        second.terminate()

        let third = XCUIApplication.optionsApp(reset: false)
        third.launch()
        editing = EditingScreen(app: third)
        editing.open()
        XCTAssertTrue(editing.waitForField("Lunch at noon today"))
    }

    /// Done starts the shout with the saved text; back returns to Editing with the keyboard up
    /// and the text intact.
    @MainActor
    func testDoneStartsShoutAndBackRestoresKeyboard() {
        let app = XCUIApplication.optionsApp(reset: true)
        app.launch()
        let editing = EditingScreen(app: app)
        editing.open()
        let softwareKeyboard = app.keyboards.firstMatch.exists

        editing.textField.typeText("Go team")
        XCTAssertTrue(editing.waitForPreview("Go team"))
        editing.textField.typeText("\n") // the Done key

        let shout = ShoutScreen(app: app)
        XCTAssertTrue(shout.waitForShout("Go team"), "the text was saved before the shout")
        XCTAssertFalse(editing.textField.isHittable)

        shout.showToolbar()
        shout.press(shout.back)
        XCTAssertTrue(shout.waitUntilGone())
        XCTAssertTrue(editing.waitForFocus(), "keyboard back up after the shout")
        XCTAssertTrue(editing.waitForField("Go team"))
        XCTAssertTrue(editing.waitForPreview("Go team"))
        if softwareKeyboard {
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        }

        // And the field still takes typing.
        editing.textField.typeText("!")
        XCTAssertTrue(editing.waitForPreview("Go team!"))
    }

    /// Turning the phone to landscape on Editing starts the shout, with the text saved.
    @MainActor
    func testRotatingToLandscapeStartsShout() {
        addTeardownBlock { @MainActor in XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.optionsApp(reset: true)
        app.launch()
        let editing = EditingScreen(app: app)
        editing.open()

        editing.textField.typeText("Turn me")
        XCTAssertTrue(editing.waitForPreview("Turn me"))
        XCUIDevice.shared.orientation = .landscapeLeft

        let shout = ShoutScreen(app: app)
        XCTAssertTrue(shout.waitForShout("Turn me"))

        // The other landscape while the shout is up does not start a second one.
        XCUIDevice.shared.orientation = .landscapeRight
        XCTAssertTrue(shout.text.exists)

        // Back with the phone still on its side: Editing, upright in portrait.
        shout.showToolbar()
        shout.press(shout.back)
        XCTAssertTrue(shout.waitUntilGone())
        XCTAssertTrue(editing.waitForFocus())
        XCTAssertTrue(editing.waitForField("Turn me"))

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(editing.waitForFocus())
        XCTAssertFalse(shout.text.exists, "turning upright on Editing does nothing")
    }

    /// Screenshots of the Editing screen with a short and a long message, kept in the result
    /// bundle (docs/rewrite/screenshots/ holds copies).
    @MainActor
    func testScreenshots() {
        let app = XCUIApplication.optionsApp(reset: true)
        app.launch()
        let editing = EditingScreen(app: app)
        editing.open()

        editing.textField.typeText("Hi Mom!")
        XCTAssertTrue(editing.waitForPreview("Hi Mom!"))
        sleep(1) // let the keyboard and push animations settle for the picture
        attach(app.screenshot(), name: "editing-short")

        editing.clearButton.tap()
        XCTAssertTrue(editing.waitForField(""))
        let long = "Can you pick up milk, eggs and bread on the way home? Also the dry cleaning, it closes at six"
        editing.textField.typeText(long)
        XCTAssertTrue(editing.waitForPreview(long))
        sleep(1)
        attach(app.screenshot(), name: "editing-long")
    }

    private func attach(_ screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
