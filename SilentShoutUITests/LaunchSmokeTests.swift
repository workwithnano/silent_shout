import XCTest

final class LaunchSmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsOptionsScreen() {
        let app = XCUIApplication.optionsApp(reset: true)
        app.launch()
        let options = OptionsScreen(app: app)
        XCTAssertTrue(options.carousel("font").waitForExistence(timeout: 30))
        XCTAssertTrue(options.carousel("texture").exists)
        XCTAssertTrue(options.carousel("lettering").exists)
        XCTAssertTrue(options.helpButton.exists)
        XCTAssertTrue(options.nextButton.exists)
        XCTAssertEqual(options.helpButton.label, "Help")
        XCTAssertEqual(options.nextButton.label, "Shout")
        // Fresh settings: the original defaults.
        XCTAssertEqual(options.value(of: "font"), "Pencil")
        XCTAssertEqual(options.value(of: "texture"), "Notecard")
        XCTAssertEqual(options.value(of: "lettering"), "Scale your note")
    }
}
