import XCTest

/// The camera background (phase 5). `-UITestPhotoFixture` makes "Choose Photo" use a picture
/// the app draws itself (a blue gradient) instead of opening the system photo picker, which a
/// test cannot drive reliably; everything after the pick (orientation fix, downscale, storing,
/// drawing) is the real path. The fixture is blue everywhere, so the tests read pixels off
/// screenshots to see which background is drawn.
final class CameraBackgroundTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func fixtureApp(reset: Bool) -> XCUIApplication {
        let app = XCUIApplication.optionsApp(reset: reset)
        app.launchArguments.append("-UITestPhotoFixture")
        return app
    }

    /// Swipes the texture carousel to the last texture, where the camera entry sits beside it.
    @MainActor
    private func swipeToCardboard(_ options: OptionsScreen, file: StaticString = #filePath, line: UInt = #line) {
        let texture = options.carousel("texture")
        while options.value(of: "texture") != "Cardboard" {
            let before = options.value(of: "texture")
            texture.swipeLeft()
            let moved = NSPredicate(format: "value != %@", before ?? "")
            XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: moved, object: texture)], timeout: 5), .completed,
                           "the texture carousel moved", file: file, line: line)
        }
    }

    /// Waits until `element` can take a tap where it is (on screen, not covered, not moving).
    @MainActor
    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Waits until a screenshot satisfies `condition` (the screen has finished changing to the
    /// state the test expects). Polls by state; no fixed delay.
    @MainActor
    private func waitForScreen(_ app: XCUIApplication, timeout: TimeInterval = 10, _ condition: @escaping @MainActor (PixelProbe) -> Bool) -> Bool {
        let predicate = NSPredicate { _, _ in
            MainActor.assumeIsolated { condition(PixelProbe(app: app)) }
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// The preview card's top-left corner (the text is centred, so the corner is background).
    @MainActor
    private static func previewCornerIsFixture(_ editing: EditingScreen, _ probe: PixelProbe) -> Bool {
        let frame = editing.preview.frame
        return PixelProbe.isFixtureBlue(probe.color(atPoint: CGPoint(x: frame.minX + 10, y: frame.minY + 10)))
    }

    /// Choose a photo, see it in the preview and the shout, and still after a relaunch.
    @MainActor
    func testChosenPhotoIsTheBackgroundAndSurvivesRelaunch() {
        XCUIDevice.shared.orientation = .portrait
        let app = fixtureApp(reset: true)
        app.launch()
        let options = OptionsScreen(app: app)
        XCTAssertTrue(options.carousel("texture").waitForExistence(timeout: 30))
        swipeToCardboard(options)

        // Beside the cardboard, not a page: the dots and the value are still the cardboard's.
        XCTAssertTrue(options.cameraButton.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForHittable(options.cameraButton), "the camera entry is on screen and reachable")
        XCTAssertEqual(options.cameraButton.label, "Camera")
        options.cameraButton.tap()
        XCTAssertTrue(options.photoChoicesTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(options.choosePhoto.exists)
        // "Take Photo" depends on the device: this simulator reports a camera, so it is not checked.
        XCTAssertFalse(options.useLastPhoto.exists, "no photo yet")
        options.choosePhoto.tap()
        XCTAssertTrue(options.waitForValue("Photo", of: "texture"), "the carousel says the photo is in use")
        XCTAssertEqual(options.cameraButton.value as? String, "Photo in use")
        XCTAssertTrue(options.cameraButton.isSelected)

        // Editing's preview is drawn on the photo.
        let editing = EditingScreen(app: app)
        options.nextButton.tap()
        XCTAssertTrue(editing.waitForFocus())
        editing.textField.typeText("Hi")
        XCTAssertTrue(editing.waitForPreview("Hi"))
        XCTAssertTrue(waitForScreen(app) { Self.previewCornerIsFixture(editing, $0) }, "the preview shows the photo")

        // So is the shout.
        editing.textField.typeText("\n")
        let shout = ShoutScreen(app: app)
        XCTAssertTrue(shout.waitForShout("Hi"))
        XCTAssertTrue(waitForScreen(app) { $0.shoutEdgesAreFixture() }, "the shout shows the photo")

        // After a relaunch (no fixture needed: the photo is stored) the photo is still in use.
        app.terminate()
        let relaunched = XCUIApplication.optionsApp(reset: false)
        relaunched.launch()
        let again = OptionsScreen(app: relaunched)
        XCTAssertTrue(again.carousel("texture").waitForExistence(timeout: 30))
        XCTAssertTrue(again.waitForValue("Photo", of: "texture"))
        XCTAssertTrue(waitForHittable(again.cameraButton), "the carousel rests beside the camera entry")
        let editingAgain = EditingScreen(app: relaunched)
        editingAgain.open()
        XCTAssertTrue(editingAgain.waitForPreview("Hi"))
        XCTAssertTrue(waitForScreen(relaunched) { Self.previewCornerIsFixture(editingAgain, $0) })
        editingAgain.textField.typeText("\n")
        let shoutAgain = ShoutScreen(app: relaunched)
        XCTAssertTrue(shoutAgain.waitForShout("Hi"))
        XCTAssertTrue(waitForScreen(relaunched) { $0.shoutEdgesAreFixture() })
    }

    /// Swiping to a paper texture switches back to it; "Use Last Photo" brings the photo back.
    @MainActor
    func testSwipingToATextureSwitchesBack() {
        XCUIDevice.shared.orientation = .portrait
        let app = fixtureApp(reset: true)
        app.launch()
        let options = OptionsScreen(app: app)
        XCTAssertTrue(options.carousel("texture").waitForExistence(timeout: 30))
        swipeToCardboard(options)
        options.cameraButton.tap()
        XCTAssertTrue(options.choosePhoto.waitForExistence(timeout: 5))
        options.choosePhoto.tap()
        XCTAssertTrue(options.waitForValue("Photo", of: "texture"))

        options.carousel("texture").swipeRight()
        XCTAssertTrue(options.waitForValue("Whiteboard", of: "texture"), "a swipe back chooses the whiteboard")
        XCTAssertEqual(options.cameraButton.value as? String ?? "", "")

        let editing = EditingScreen(app: app)
        editing.open()
        editing.textField.typeText("Paper")
        XCTAssertTrue(editing.waitForPreview("Paper"))
        XCTAssertTrue(waitForScreen(app) { !Self.previewCornerIsFixture(editing, $0) }, "the preview is on paper again")
        editing.textField.typeText("\n")
        let shout = ShoutScreen(app: app)
        XCTAssertTrue(shout.waitForShout("Paper"))
        XCTAssertTrue(waitForScreen(app) { $0.shoutEdgesAreNotFixture() }, "the shout is on paper again")

        // Back to Options; the stored photo can come back without picking it again.
        shout.showToolbar()
        shout.press(shout.doubleBack)
        XCTAssertTrue(shout.waitUntilGone())
        XCTAssertTrue(options.carousel("texture").waitForExistence(timeout: 5))
        swipeToCardboard(options)
        options.cameraButton.tap()
        XCTAssertTrue(options.useLastPhoto.waitForExistence(timeout: 5))
        options.useLastPhoto.tap()
        XCTAssertTrue(options.waitForValue("Photo", of: "texture"))
    }

    /// Pictures for docs/rewrite/screenshots/: Options with the camera entry, then with the
    /// photo in use, and the preview and shout on the photo.
    @MainActor
    func testCameraScreenshots() {
        addTeardownBlock { @MainActor in XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        let app = fixtureApp(reset: true)
        app.launch()
        let options = OptionsScreen(app: app)
        XCTAssertTrue(options.carousel("texture").waitForExistence(timeout: 30))
        swipeToCardboard(options)
        XCTAssertTrue(options.cameraButton.waitForExistence(timeout: 5))
        attach("options-camera")
        options.cameraButton.tap()
        XCTAssertTrue(options.choosePhoto.waitForExistence(timeout: 5))
        attach("options-camera-choices")
        options.choosePhoto.tap()
        XCTAssertTrue(options.waitForValue("Photo", of: "texture"))
        attach("options-camera-photo")

        let editing = EditingScreen(app: app)
        options.nextButton.tap()
        XCTAssertTrue(editing.waitForFocus())
        editing.textField.typeText("Welcome home!")
        XCTAssertTrue(editing.waitForPreview("Welcome home!"))
        XCTAssertTrue(waitForScreen(app) { Self.previewCornerIsFixture(editing, $0) })
        attach("editing-photo")

        XCUIDevice.shared.orientation = .landscapeLeft
        let shout = ShoutScreen(app: app)
        XCTAssertTrue(shout.waitForShout("Welcome home!"))
        XCTAssertTrue(waitForScreen(app) { $0.shoutEdgesAreFixture() })
        attach("shout-photo")
    }

    @MainActor
    private func attach(_ name: String) {
        sleep(1) // pictures only (as phase 4's screenshots): let the fade settle; no assertion depends on it
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
