import XCTest

/// Queries for the Shout screen. Identifiers match `ShoutAccessibilityID` in the app.
@MainActor
struct ShoutScreen {
    let app: XCUIApplication

    /// The whole shout as one element: label is the message, value is "Scrolling" while the
    /// marquee moves, empty otherwise.
    var text: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "shout.text").firstMatch
    }
    var back: XCUIElement { app.buttons["shout.back"] }
    var doubleBack: XCUIElement { app.buttons["shout.doubleBack"] }
    /// The export button (1.0.1's share art), in the toolbar.
    var share: XCUIElement { app.buttons["shout.share"] }

    // The "Export Shout" sheet.
    var exportTitle: XCUIElement { app.staticTexts["Export Shout"] }
    var saveToCameraRoll: XCUIElement { app.buttons["Save to Camera Roll"] }
    var sendInMessages: XCUIElement { app.buttons["Send in iMessage"] }
    var cancel: XCUIElement { app.buttons["Cancel"] }
    /// "Saved to Photos", shown briefly after a save.
    var savedNote: XCUIElement { app.descendants(matching: .any).matching(identifier: "shout.saved").firstMatch }

    @discardableResult
    func waitForExportSheet(visible: Bool = true, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == %@", NSNumber(value: visible))
        return wait(for: predicate, on: exportTitle, timeout: timeout)
            && wait(for: predicate, on: saveToCameraRoll, timeout: timeout)
    }

    @discardableResult
    func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        wait(for: NSPredicate(format: "exists == false"), on: element, timeout: timeout)
    }

    /// Waits until the shout is up showing `message`.
    @discardableResult
    func waitForShout(_ message: String, timeout: TimeInterval = 10) -> Bool {
        wait(for: NSPredicate(format: "exists == true AND label == %@", message), on: text, timeout: timeout)
    }

    @discardableResult
    func waitForValue(_ value: String, timeout: TimeInterval = 5) -> Bool {
        wait(for: NSPredicate(format: "value == %@", value), on: text, timeout: timeout)
    }

    /// The toolbar is in the view tree only while it shows, so its buttons exist only then.
    ///
    /// Not `hittable`: with the interface in landscape, XCUITest reports the corner buttons as
    /// not hittable ("Computed hit point {-1, -1}") although they are on top and a touch at
    /// their position works; only the large centred message passes that check. See `press`.
    @discardableResult
    func waitForToolbar(visible: Bool, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == %@", NSNumber(value: visible))
        return wait(for: predicate, on: back, timeout: timeout)
            && wait(for: predicate, on: doubleBack, timeout: timeout)
    }

    /// Taps the middle of the shout (away from the toolbar) and waits for the toolbar to show.
    func showToolbar(file: StaticString = #filePath, line: UInt = #line) {
        text.tap()
        XCTAssertTrue(waitForToolbar(visible: true), "a tap shows the toolbar", file: file, line: line)
    }

    /// Taps a toolbar button with a real touch at its centre. `XCUIElement.tap()` cannot compute
    /// a hit point for these buttons (see `waitForToolbar`) and falls back to activating them
    /// through accessibility, which would not prove that a finger reaches them.
    func press(_ button: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(button.exists, "\(button) is showing", file: file, line: line)
        let frame = button.frame
        app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.midX, dy: frame.midY))
            .tap()
    }

    @discardableResult
    func waitUntilGone(timeout: TimeInterval = 10) -> Bool {
        wait(for: NSPredicate(format: "exists == false"), on: text, timeout: timeout)
    }

    private func wait(for predicate: NSPredicate, on element: XCUIElement, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
