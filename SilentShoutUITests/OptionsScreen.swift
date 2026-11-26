import XCTest

@MainActor
extension XCUIApplication {
    /// The app, optionally told to clear its stored settings before it starts
    /// (`ShoutSettings.resetLaunchArgument`, debug builds only).
    static func optionsApp(reset: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        if reset { app.launchArguments.append("-UITestResetSettings") }
        return app
    }
}

/// Queries for the Options screen. Identifiers match `OptionsAccessibilityID` in the app.
@MainActor
struct OptionsScreen {
    let app: XCUIApplication

    /// `key` is the carousel's UserDefaults key: `font`, `texture` or `lettering`.
    func carousel(_ key: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "options.carousel.\(key)").firstMatch
    }

    func value(of key: String) -> String? {
        carousel(key).value as? String
    }

    func bubble(_ key: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "options.help.bubble.\(key)").firstMatch
    }

    var helpButton: XCUIElement { app.buttons["options.help"] }
    var nextButton: XCUIElement { app.buttons["options.next"] }

    /// Waits until the carousel's accessibility value equals `expected`.
    @discardableResult
    func waitForValue(_ expected: String, of key: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "value == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: carousel(key))
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
