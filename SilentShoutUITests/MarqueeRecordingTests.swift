import XCTest

/// A recording aid, not a test: holds the app on a scrolling shout so `make record-marquee` can
/// film the simulator and sample the app's CPU. Skipped unless the run asks for it, so the
/// normal `make test-ui` suite neither runs it nor waits for it.
///
/// `make record-marquee` passes `TEST_RUNNER_MARQUEE_RECORD_DIR=<abs dir>` to xcodebuild, which
/// hands the runner `MARQUEE_RECORD_DIR` (xcodebuild strips the prefix). The test and the
/// recording script then take turns through marker files in that directory:
///
/// 1. the test writes `ready` with the message typed and the shout about to start;
/// 2. the script starts `simctl io recordVideo`, and writes `recording` once the recorder says
///    it has started;
/// 3. the test turns the phone to landscape (which starts the shout), waits for it, writes
///    `shouting`, holds, and writes `done`; the script stops the recorder on `done`.
final class MarqueeRecordingTests: XCTestCase {
    static let message = "Happy birthday Sam! We are over here by the cake"

    @MainActor
    func testHoldScrollingShoutForRecording() throws {
        guard let path = ProcessInfo.processInfo.environment["MARQUEE_RECORD_DIR"], !path.isEmpty else {
            throw XCTSkip("Recording aid: run with `make record-marquee OUT=<file>`.")
        }
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        addTeardownBlock { @MainActor in XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait

        // Scroll mode, the red dry-erase marker (Kristi) on the notecard.
        let app = XCUIApplication.optionsApp(font: 1, texture: 0, lettering: 1)
        app.launch()
        let editing = EditingScreen(app: app)
        editing.open()
        editing.textField.typeText(Self.message)
        XCTAssertTrue(editing.waitForPreview(Self.message))

        try mark("ready", in: dir)
        XCTAssertTrue(waitForMarker("recording", in: dir, timeout: 60), "the script started the recorder")

        XCUIDevice.shared.orientation = .landscapeLeft
        let shout = ShoutScreen(app: app)
        XCTAssertTrue(shout.waitForShout(Self.message))
        XCTAssertTrue(shout.waitForValue("Scrolling"))
        try mark("shouting", in: dir)

        // A fixed hold is right here: this only keeps the marquee on screen for the camera and
        // the CPU samples. Nothing is asserted about what happens during it.
        Thread.sleep(forTimeInterval: 14)
        try mark("done", in: dir)
        app.terminate()
    }

    private func mark(_ name: String, in dir: URL) throws {
        try Data(name.utf8).write(to: dir.appendingPathComponent(name))
    }

    private func waitForMarker(_ name: String, in dir: URL, timeout: TimeInterval) -> Bool {
        let file = dir.appendingPathComponent(name).path
        let predicate = NSPredicate { _, _ in FileManager.default.fileExists(atPath: file) }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
