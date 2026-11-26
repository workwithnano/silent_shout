import XCTest

final class LaunchSmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsPlaceholderWithEveryFontLoaded() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["placeholder.title"].waitForExistence(timeout: 30))
        for index in 0..<3 {
            let label = app.staticTexts["placeholder.font.\(index)"]
            XCTAssertTrue(label.exists, "font row \(index) missing")
            XCTAssertTrue(label.label.hasSuffix("loaded"), "font row \(index): \(label.label)")
        }
    }
}
