import XCTest

final class OptionsScreenTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Swiping each carousel one page stores the new choice; it is still chosen after a relaunch.
    @MainActor
    func testEachCarouselChoiceSurvivesRelaunch() {
        let app = XCUIApplication.optionsApp(reset: true)
        app.launch()
        let options = OptionsScreen(app: app)
        XCTAssertTrue(options.carousel("font").waitForExistence(timeout: 30))

        let expected = [
            ("font", "Pencil", "Red dry-erase marker"),
            ("texture", "Notecard", "Whiteboard"),
            ("lettering", "Scale your note", "Scroll your note"),
        ]
        for (key, before, after) in expected {
            XCTAssertEqual(options.value(of: key), before, key)
            options.carousel(key).swipeLeft()
            XCTAssertTrue(options.waitForValue(after, of: key), "\(key) is \(options.value(of: key) ?? "nil") after a swipe")
        }

        // Swiping past the last lettering option keeps the last one (clamped, no wrap).
        options.carousel("lettering").swipeLeft()
        XCTAssertTrue(options.waitForValue("Scroll your note", of: "lettering"))

        app.terminate()
        let relaunched = XCUIApplication.optionsApp(reset: false)
        relaunched.launch()
        let again = OptionsScreen(app: relaunched)
        XCTAssertTrue(again.carousel("font").waitForExistence(timeout: 30))
        for (key, _, after) in expected {
            XCTAssertEqual(again.value(of: key), after, "\(key) after relaunch")
        }

        // And back: a right swipe returns to the first option.
        again.carousel("font").swipeRight()
        XCTAssertTrue(again.waitForValue("Pencil", of: "font"))
    }

    @MainActor
    func testHelpOverlayTogglesOnAndOff() {
        let app = XCUIApplication.optionsApp(reset: true)
        app.launch()
        let options = OptionsScreen(app: app)
        XCTAssertTrue(options.helpButton.waitForExistence(timeout: 30))
        let keys = ["font", "texture", "lettering"]

        for key in keys { XCTAssertFalse(options.bubble(key).exists, "\(key) bubble shown before help") }
        XCTAssertFalse(options.helpButton.isSelected)

        options.helpButton.tap()
        for key in keys { XCTAssertTrue(options.bubble(key).waitForExistence(timeout: 3), "\(key) bubble missing") }
        XCTAssertEqual(options.bubble("font").label, "Writing Tool")
        XCTAssertTrue(options.helpButton.isSelected)

        // The overlay never blocks touches: the carousels still work under it.
        options.carousel("font").swipeLeft()
        XCTAssertTrue(options.waitForValue("Red dry-erase marker", of: "font"))

        options.helpButton.tap()
        let gone = NSPredicate(format: "exists == false")
        for key in keys {
            let expectation = XCTNSPredicateExpectation(predicate: gone, object: options.bubble(key))
            XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 3), .completed, "\(key) bubble still shown")
        }
        XCTAssertFalse(options.helpButton.isSelected)
    }

    @MainActor
    func testNextOpensEditingAndBackReturns() {
        let app = XCUIApplication.optionsApp(reset: true)
        app.launch()
        let options = OptionsScreen(app: app)
        XCTAssertTrue(options.nextButton.waitForExistence(timeout: 30))

        options.nextButton.tap()
        XCTAssertTrue(options.editingPlaceholder.waitForExistence(timeout: 5))
        XCTAssertFalse(options.nextButton.isHittable)

        options.editingBack.tap()
        XCTAssertTrue(options.nextButton.waitForExistence(timeout: 5))
        XCTAssertTrue(options.carousel("font").waitForExistence(timeout: 5))
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: options.editingPlaceholder)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed)
    }

    /// Screenshots of the Options screen, help off and help on, kept in the result bundle
    /// (docs/rewrite/screenshots/ holds copies).
    @MainActor
    func testScreenshots() {
        let app = XCUIApplication.optionsApp(reset: true)
        app.launch()
        let options = OptionsScreen(app: app)
        XCTAssertTrue(options.helpButton.waitForExistence(timeout: 30))
        sleep(1)
        attach(app.screenshot(), name: "options")

        options.helpButton.tap()
        XCTAssertTrue(options.bubble("lettering").waitForExistence(timeout: 3))
        sleep(1) // let the 0.5 s fade finish
        attach(app.screenshot(), name: "options-help")
    }

    private func attach(_ screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
