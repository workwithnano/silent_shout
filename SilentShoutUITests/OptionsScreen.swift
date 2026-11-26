import XCTest

@MainActor
extension XCUIApplication {
    /// The app, optionally told to clear its stored settings before it starts
    /// (`UITestHooks.resetSettings` in the app, debug builds only).
    static func optionsApp(reset: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        if reset { app.launchArguments.append("-UITestResetSettings") }
        // The shout's state probe (DEBUG, invisible): `ShoutScreen.showToolbar` waits on it.
        app.launchArguments.append("-UITestShoutState")
        return app
    }

    /// A fresh app with options chosen through the launch arguments (the argument domain
    /// overrides the stored values for this launch only), so tests reach a texture, font or
    /// sizing without swiping the carousels. Indexes as stored: `font`, `texture`, `lettering`.
    static func optionsApp(font: Int = 0, texture: Int = 0, lettering: Int = 0) -> XCUIApplication {
        let app = optionsApp(reset: true)
        app.launchArguments += ["-font", String(font), "-texture", String(texture), "-lettering", String(lettering)]
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

    /// The camera entry beside the last texture (phase 5).
    var cameraButton: XCUIElement { app.buttons["options.camera"] }
    var choosePhoto: XCUIElement { app.buttons["Choose Photo"] }
    var takePhoto: XCUIElement { app.buttons["Take Photo"] }
    var useLastPhoto: XCUIElement { app.buttons["Use Last Photo"] }
    var photoChoicesTitle: XCUIElement { app.staticTexts["Background Photo"] }

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
