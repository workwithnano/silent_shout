import XCTest

/// Queries for the Editing screen. Identifiers match `EditingAccessibilityID` in the app.
@MainActor
struct EditingScreen {
    let app: XCUIApplication

    var textField: XCUIElement { app.textFields["editing.textField"] }
    var backButton: XCUIElement { app.buttons["editing.back"] }
    /// The preview card; its accessibility value is the text it draws.
    var preview: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "editing.preview").firstMatch
    }
    var clearButton: XCUIElement { textField.buttons.firstMatch }

    /// From a freshly launched app on Options: Next, then wait until the field has the keyboard.
    func open(file: StaticString = #filePath, line: UInt = #line) {
        let next = app.buttons["options.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 30), file: file, line: line)
        next.tap()
        XCTAssertTrue(textField.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(waitForFocus(), "the field should have the keyboard on arrival", file: file, line: line)
    }

    /// Waits until the field is first responder (the keyboard is up for it).
    @discardableResult
    func waitForFocus(timeout: TimeInterval = 5) -> Bool {
        wait(for: NSPredicate(format: "hasKeyboardFocus == true"), on: textField, timeout: timeout)
    }

    @discardableResult
    func waitForPreview(_ text: String, timeout: TimeInterval = 5) -> Bool {
        wait(for: NSPredicate(format: "value == %@", text), on: preview, timeout: timeout)
    }

    @discardableResult
    func waitForField(_ text: String, timeout: TimeInterval = 5) -> Bool {
        wait(for: NSPredicate(format: "value == %@", text), on: textField, timeout: timeout)
    }

    @discardableResult
    func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        wait(for: NSPredicate(format: "exists == false"), on: element, timeout: timeout)
    }

    private func wait(for predicate: NSPredicate, on element: XCUIElement, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
