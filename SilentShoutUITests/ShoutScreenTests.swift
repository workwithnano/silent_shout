import XCTest

final class ShoutScreenTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Opens Editing on a fresh app, types `message` and presses Done.
    @MainActor
    private func shoutWithDone(_ app: XCUIApplication, message: String) -> (EditingScreen, ShoutScreen) {
        app.launch()
        let editing = EditingScreen(app: app)
        editing.open()
        editing.textField.typeText(message)
        XCTAssertTrue(editing.waitForPreview(message))
        editing.textField.typeText("\n") // the Done key
        let shout = ShoutScreen(app: app)
        XCTAssertTrue(shout.waitForShout(message), "the shout shows the message")
        return (editing, shout)
    }

    /// Done reaches the real shout (fit mode): the message as one element, no toolbar until a
    /// tap, and a second tap hides it again. With the phone upright the shout stays up.
    @MainActor
    func testDoneShowsShoutAndTapTogglesToolbar() {
        XCUIDevice.shared.orientation = .portrait
        let (editing, shout) = shoutWithDone(.optionsApp(reset: true), message: "Go team")
        XCTAssertEqual(shout.text.value as? String, "", "fit mode does not scroll")
        XCTAssertFalse(editing.textField.isHittable)
        XCTAssertTrue(shout.waitForToolbar(visible: false), "the toolbar starts hidden")

        shout.showToolbar()
        XCTAssertEqual(shout.back.label, "Back 1 Step")
        XCTAssertEqual(shout.doubleBack.label, "Back 2 Steps")

        // A tap near the left edge, outside the safe area (below the Dynamic Island, which sits
        // mid-height on that side here), counts too. Offsets from the window's origin in points,
        // as `ShoutScreen.press` uses: with the interface turned and the phone upright, a
        // normalized offset lands elsewhere.
        let window = shout.app.windows.firstMatch
        window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 20, dy: window.frame.height * 0.85)).tap()
        XCTAssertTrue(shout.waitForToolbar(visible: false), "a second tap hides it")
        XCTAssertTrue(shout.text.exists, "still shouting with the phone upright")

        shout.showToolbar()
        shout.press(shout.back)
        XCTAssertTrue(shout.waitUntilGone())
        XCTAssertTrue(editing.waitForFocus(), "back returns to Editing with the keyboard up")
        XCTAssertTrue(editing.waitForField("Go team"))
    }

    /// Double-back goes past Editing to Options; the message is still there next time.
    @MainActor
    func testDoubleBackReturnsToOptions() {
        let app = XCUIApplication.optionsApp(reset: true)
        let (editing, shout) = shoutWithDone(app, message: "See you")
        shout.showToolbar()
        shout.press(shout.doubleBack)

        XCTAssertTrue(shout.waitUntilGone())
        let next = app.buttons["options.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertTrue(editing.waitUntilGone(editing.textField), "Editing was popped")
        XCTAssertTrue(next.isHittable)

        next.tap()
        XCTAssertTrue(editing.waitForField("See you"))
        XCTAssertTrue(editing.waitForFocus())
    }

    /// Turning the phone on its side starts the shout, flipping it keeps the shout, and turning
    /// it upright returns to Editing with the keyboard up.
    @MainActor
    func testRotationStartsShoutAndPortraitEndsIt() {
        addTeardownBlock { @MainActor in XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.optionsApp(reset: true)
        app.launch()
        let editing = EditingScreen(app: app)
        editing.open()
        editing.textField.typeText("Over here")
        XCTAssertTrue(editing.waitForPreview("Over here"))

        XCUIDevice.shared.orientation = .landscapeRight
        let shout = ShoutScreen(app: app)
        XCTAssertTrue(shout.waitForShout("Over here"))
        XCUIDevice.shared.orientation = .landscapeLeft
        shout.showToolbar() // still up, and still takes taps
        XCTAssertTrue(shout.text.exists)

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(shout.waitUntilGone(), "turning upright leaves the shout")
        XCTAssertTrue(editing.waitForFocus())
        XCTAssertTrue(editing.waitForField("Over here"))
    }

    /// A shout started by Done with the phone upright leaves on portrait only after the phone
    /// has been on its side (ShoutLeaveRule).
    @MainActor
    func testDoneShoutLeavesOnPortraitOnlyAfterLandscape() {
        addTeardownBlock { @MainActor in XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        let (editing, shout) = shoutWithDone(.optionsApp(reset: true), message: "Wait")
        // Upright the whole time: a full toolbar round trip later it is still up.
        shout.showToolbar()
        shout.text.tap()
        XCTAssertTrue(shout.waitForToolbar(visible: false))
        XCTAssertTrue(shout.text.exists)

        XCUIDevice.shared.orientation = .landscapeLeft
        shout.showToolbar()
        XCTAssertTrue(shout.text.exists)
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(shout.waitUntilGone())
        XCTAssertTrue(editing.waitForFocus())
    }

    /// Scroll mode: the message runs as a marquee; a short message sits still.
    @MainActor
    func testScrollModeShowsTheMarquee() {
        let app = XCUIApplication.optionsApp(lettering: 1)
        let long = "Can you pick up milk on the way home?"
        let (editing, shout) = shoutWithDone(app, message: long)
        XCTAssertTrue(shout.waitForValue("Scrolling"), "a long message scrolls")

        shout.showToolbar()
        shout.press(shout.back)
        XCTAssertTrue(shout.waitUntilGone())
        XCTAssertTrue(editing.waitForFocus())
        editing.clearButton.tap()
        XCTAssertTrue(editing.waitForField(""))
        editing.textField.typeText("Hi\n")
        XCTAssertTrue(shout.waitForShout("Hi"))
        XCTAssertEqual(shout.text.value as? String, "", "a short message does not scroll")
    }

    /// The marquee really moves on screen (Core Animation moves it in the render server, so
    /// only the pixels show it): the middle band of the screen changes while the shout is up.
    @MainActor
    func testMarqueeMovesOnScreen() {
        addTeardownBlock { @MainActor in XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication.optionsApp(font: 1, texture: 0, lettering: 1)
        let message = "Happy birthday Sam! We are over here by the cake"
        let (_, shout) = shoutWithDone(app, message: message)
        XCTAssertTrue(shout.waitForValue("Scrolling"))

        // The landscape screen's middle band is the middle column of the portrait screenshot.
        let points = stride(from: 0.04, through: 0.96, by: 0.02).flatMap { y in [0.47, 0.5, 0.53].map { (x: $0, y: y) } }
        func band() -> [(r: Int, g: Int, b: Int)] {
            let probe = PixelProbe(app: app)
            return points.map { probe.color(atNormalized: $0.x, $0.y) }
        }
        func changed(_ a: [(r: Int, g: Int, b: Int)], _ b: [(r: Int, g: Int, b: Int)]) -> Int {
            zip(a, b).filter { abs($0.r - $1.r) + abs($0.g - $1.g) + abs($0.b - $1.b) > 90 }.count
        }
        let first = band()
        let moved = NSPredicate { _, _ in MainActor.assumeIsolated { changed(first, band()) >= 6 } }
        let expectation = XCTNSPredicateExpectation(predicate: moved, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 10), .completed, "the text moves across the screen")
        // And keeps moving (past the lead-in, into the repeating part).
        let second = band()
        let movedAgain = NSPredicate { _, _ in MainActor.assumeIsolated { changed(second, band()) >= 6 } }
        let again = XCTNSPredicateExpectation(predicate: movedAgain, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [again], timeout: 10), .completed, "the text is still moving")
    }

    /// Pictures of the shout for docs/rewrite/screenshots/ (kept in the result bundle): fit with
    /// a short and a long message, scroll, and the toolbar, over different textures and fonts
    /// and both landscape directions.
    @MainActor
    func testScreenshots() {
        addTeardownBlock { @MainActor in XCUIDevice.shared.orientation = .portrait }
        let shots: [(name: String, font: Int, texture: Int, lettering: Int, message: String, orientation: UIDeviceOrientation, toolbar: Bool)] = [
            ("shout-fit-short", 0, 0, 0, "Hi Mom!", .landscapeLeft, false),
            ("shout-fit-long", 1, 1, 0, "Can you pick up milk, eggs and bread on the way home? Also the dry cleaning, it closes at six", .landscapeRight, false),
            ("shout-fit-keyboard", 2, 2, 0, "Gate B12", .landscapeLeft, false),
            ("shout-scroll", 2, 2, 1, "Welcome home from Kyoto, Grandma and Grandpa!", .landscapeLeft, false),
            ("shout-toolbar", 1, 0, 1, "Happy birthday Sam!", .landscapeRight, true),
        ]
        for shot in shots {
            XCUIDevice.shared.orientation = .portrait
            let app = XCUIApplication.optionsApp(font: shot.font, texture: shot.texture, lettering: shot.lettering)
            app.launch()
            let editing = EditingScreen(app: app)
            editing.open()
            editing.textField.typeText(shot.message)
            XCTAssertTrue(editing.waitForPreview(shot.message))
            XCUIDevice.shared.orientation = shot.orientation
            let shout = ShoutScreen(app: app)
            XCTAssertTrue(shout.waitForShout(shot.message), shot.name)
            if shot.toolbar { shout.showToolbar() }
            sleep(1) // let the dissolve and rotation settle for the picture
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = shot.name
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        }
    }
}
