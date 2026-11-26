import Foundation
import Testing
import UIKit
@testable import SilentShout

/// Reads one pixel of an image as 0...255 RGB.
private func pixel(_ image: UIImage, x: Int, y: Int) -> (r: Int, g: Int, b: Int) {
    guard let cgImage = image.cgImage else { return (0, 0, 0) }
    var data = [UInt8](repeating: 0, count: 4)
    let space = CGColorSpaceCreateDeviceRGB()
    data.withUnsafeMutableBytes { buffer in
        guard let context = CGContext(
            data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }
        context.draw(cgImage, in: CGRect(x: -x, y: -(cgImage.height - 1 - y), width: cgImage.width, height: cgImage.height))
    }
    return (Int(data[0]), Int(data[1]), Int(data[2]))
}

/// A solid-colour image of `size` pixels.
private func solid(_ color: UIColor, size: CGSize, orientation: UIImage.Orientation = .up) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
        color.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
    return UIImage(cgImage: image.cgImage!, scale: 1, orientation: orientation)
}

@MainActor
@Suite("Export")
struct ExportTests {
    /// The iPhone 17 Pro's landscape screen.
    let screen = CGSize(width: 874, height: 402)

    private func scene(_ sizing: ShoutSizing, background: ShoutBackground = .texture(.notecard)) -> ShoutScene {
        ShoutScene(text: "Can you pick up milk on the way home?", font: .pencil, sizing: sizing, background: background)
    }

    /// Both modes export at the screen's pixel size, with something drawn (PLAN ruling 8).
    @Test(arguments: [ShoutSizing.scaleToFit, .scroll])
    func exportIsScreenPixelSize(_ sizing: ShoutSizing) throws {
        let image = ShoutExport.image(of: scene(sizing), size: screen, scale: 3)
        #expect(image.size == screen)
        #expect(image.scale == 3)
        let cgImage = try #require(image.cgImage)
        #expect(cgImage.width == 2622)
        #expect(cgImage.height == 1206)
        let data = try #require(ShoutExport.pngData(of: scene(sizing), size: screen, scale: 3))
        #expect(data.count > 10_000)
        #expect(UIImage(data: data)?.size == CGSize(width: 2622, height: 1206))
    }

    /// The export has the text in it in both modes: it differs from the bare background.
    @Test(arguments: [ShoutSizing.scaleToFit, .scroll])
    func exportIncludesTheText(_ sizing: ShoutSizing) throws {
        let withText = try #require(ShoutExport.pngData(of: scene(sizing), size: screen, scale: 1))
        let bare = try #require(ShoutRenderer.image(of: scene(sizing), size: screen, scale: 1, content: .backgroundOnly).pngData())
        #expect(withText != bare)
    }

    /// A photo background is exported aspect-filled under the text.
    @Test func exportOnAPhotoBackground() throws {
        let photo = ShoutBackground(id: "photo-test", image: solid(UIColor(red: 0, green: 0, blue: 1, alpha: 1), size: CGSize(width: 300, height: 600)))
        let image = ShoutExport.image(of: scene(.scaleToFit, background: photo), size: screen, scale: 2)
        #expect(image.size == screen)
        #expect(image.cgImage?.width == 1748)
        // A corner, outside the 480x320 canvas the text is fitted in, is the photo's blue.
        let corner = pixel(image, x: 10, y: 10)
        #expect(corner.b > 200 && corner.r < 40 && corner.g < 40)
    }

    // MARK: Availability

    private struct Availability: MessageAvailability {
        let canSendImage: Bool
    }

    @Test func messagesOfferedWhenTheDeviceCanSend() {
        #expect(ExportAction.available(messages: Availability(canSendImage: true)) == [.saveToCameraRoll, .sendInMessages])
    }

    @Test func messagesHiddenWhenTheDeviceCannot() {
        #expect(ExportAction.available(messages: Availability(canSendImage: false)) == [.saveToCameraRoll])
    }

    @Test func originalTitlesInOrder() {
        #expect(ExportAction.allCases.map(\.title) == ["Save to Camera Roll", "Send in iMessage"])
    }

    /// The simulator cannot send messages, so the real check says no there.
    @Test func simulatorCannotSendMessages() {
        #if targetEnvironment(simulator)
        #expect(!DeviceMessageAvailability().canSendImage)
        #endif
    }

    @Test func fakeSaverAnswersAsAsked() async {
        #expect(await FakePhotoLibrarySaver(result: .saved).save(Data()) == .saved)
        #expect(await FakePhotoLibrarySaver(result: .denied).save(Data()) == .denied)
    }
}

@Suite("Photo processing")
struct PhotoProcessingTests {
    @Test func downscalesToTheLongestEdge() {
        #expect(PhotoProcessing.targetPixelSize(for: CGSize(width: 4032, height: 3024), maxPixelLength: 2622) == CGSize(width: 2622, height: 1967))
        #expect(PhotoProcessing.targetPixelSize(for: CGSize(width: 3024, height: 4032), maxPixelLength: 2622) == CGSize(width: 1967, height: 2622))
    }

    @Test func neverUpscales() {
        #expect(PhotoProcessing.targetPixelSize(for: CGSize(width: 800, height: 600), maxPixelLength: 2622) == CGSize(width: 800, height: 600))
    }

    @Test func degenerateSizes() {
        #expect(PhotoProcessing.targetPixelSize(for: .zero, maxPixelLength: 100) == .zero)
        #expect(PhotoProcessing.targetPixelSize(for: CGSize(width: 10_000, height: 1), maxPixelLength: 100) == CGSize(width: 100, height: 1))
    }

    @MainActor
    @Test func maxPixelLengthIsTheLongestScreenEdge() {
        #expect(PhotoProcessing.maxPixelLength(screenSize: CGSize(width: 402, height: 874), scale: 3) == 2622)
    }

    /// A camera photo stored sideways (EXIF orientation `.right`) comes out upright, at scale 1
    /// and within the limit: the stored image's left half (red) becomes the top.
    @Test func normalisesOrientationAndDownscales() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let raw = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 200), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 200, y: 0, width: 200, height: 200))
        }
        let sideways = UIImage(cgImage: try #require(raw.cgImage), scale: 1, orientation: .right)
        #expect(sideways.size == CGSize(width: 200, height: 400))

        let prepared = PhotoProcessing.prepared(sideways, maxPixelLength: 100)
        #expect(prepared.imageOrientation == .up)
        #expect(prepared.scale == 1)
        let cgImage = try #require(prepared.cgImage)
        #expect(cgImage.width == 50)
        #expect(cgImage.height == 100)
        let top = pixel(prepared, x: 25, y: 10)
        let bottom = pixel(prepared, x: 25, y: 90)
        #expect(top.r > 200 && top.b < 50)
        #expect(bottom.b > 200 && bottom.r < 50)
    }
}

@MainActor
@Suite("Photo background store and settings")
final class PhotoBackgroundTests {
    let suiteName = "PhotoBackgroundTests.\(UUID().uuidString)"
    let defaults: UserDefaults
    let store: PhotoBackgroundStore

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
        store = PhotoBackgroundStore(directory: FileManager.default.temporaryDirectory
            .appending(path: "PhotoBackgroundTests-\(UUID().uuidString)", directoryHint: .isDirectory))
    }

    deinit {
        UserDefaults().removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: store.directory)
    }

    private var photo: UIImage { solid(.blue, size: CGSize(width: 300, height: 200)) }

    @Test func saveThenLoad() throws {
        #expect(!store.hasPhoto)
        #expect(store.load() == nil)
        let saved = try store.save(photo)
        #expect(store.hasPhoto)
        let loaded = try #require(store.load())
        #expect(loaded.id == saved.id)
        #expect(loaded.id.hasPrefix("photo-"))
        #expect(loaded.image.size == CGSize(width: 300, height: 200))
        store.remove()
        #expect(!store.hasPhoto)
    }

    @Test func newPhotoNewID() throws {
        let first = try store.save(photo)
        let second = try store.save(solid(.red, size: CGSize(width: 300, height: 200)))
        #expect(first.id != second.id)
    }

    @Test func photoIsOffByDefault() {
        let settings = ShoutSettings(defaults: defaults, photoStore: store)
        #expect(!settings.usesPhoto)
        #expect(settings.background.id == ShoutTexture.notecard.shoutImageName)
        #expect(settings.activePhoto == nil)
        #expect(!settings.hasStoredPhoto)
    }

    /// The photo, once chosen, is the background after a relaunch; `texture` keeps its value.
    @Test func roundTripWithPhotoActive() throws {
        let settings = ShoutSettings(defaults: defaults, photoStore: store)
        settings.texture = .whiteboard
        try settings.usePhoto(photo)
        #expect(settings.usesPhoto)
        #expect(settings.background.id.hasPrefix("photo-"))
        #expect(settings.photoThumbnail != nil)
        #expect(defaults.bool(forKey: ShoutSettings.Key.photoBackground))
        #expect(defaults.integer(forKey: ShoutSettings.Key.texture) == 1)

        let relaunched = ShoutSettings(defaults: defaults, photoStore: store)
        #expect(relaunched.usesPhoto)
        #expect(relaunched.texture == .whiteboard)
        #expect(relaunched.background.id == settings.background.id)
        #expect(relaunched.activePhoto?.size == CGSize(width: 300, height: 200))
    }

    /// A missing file falls back to the texture rather than a blank background, and the flag
    /// is cleared.
    @Test func missingFileFallsBackToTheTexture() throws {
        let settings = ShoutSettings(defaults: defaults, photoStore: store)
        settings.texture = .cardboard
        try settings.usePhoto(photo)
        store.remove()

        let relaunched = ShoutSettings(defaults: defaults, photoStore: store)
        #expect(!relaunched.usesPhoto)
        #expect(relaunched.background.id == ShoutTexture.cardboard.shoutImageName)
        #expect(!defaults.bool(forKey: ShoutSettings.Key.photoBackground))
        #expect(!relaunched.useLastPhoto())
    }

    /// Choosing a texture switches back; the photo stays stored for "Use Last Photo".
    @Test func textureSwitchesBackAndLastPhotoReturns() throws {
        let settings = ShoutSettings(defaults: defaults, photoStore: store)
        try settings.usePhoto(photo)
        let id = settings.background.id
        settings.useTexture(.whiteboard)
        #expect(!settings.usesPhoto)
        #expect(settings.texture == .whiteboard)
        #expect(settings.background.id == ShoutTexture.whiteboard.shoutImageName)
        #expect(settings.hasStoredPhoto)

        let relaunched = ShoutSettings(defaults: defaults, photoStore: store)
        #expect(!relaunched.usesPhoto)
        #expect(relaunched.hasStoredPhoto)
        #expect(relaunched.useLastPhoto())
        #expect(relaunched.usesPhoto)
        #expect(relaunched.background.id == id)
    }

    /// The photo key does not change how `texture` is read: 3 still clamps to cardboard.
    @Test func textureClampingUnchanged() {
        defaults.set(3, forKey: ShoutSettings.Key.texture)
        defaults.set(true, forKey: ShoutSettings.Key.photoBackground)
        let settings = ShoutSettings(defaults: defaults, photoStore: store)
        #expect(settings.texture == .cardboard)
        #expect(!settings.usesPhoto, "no file, so no photo")
    }

    @Test func resetRemovesThePhoto() throws {
        let settings = ShoutSettings(defaults: defaults, photoStore: store)
        try settings.usePhoto(photo)
        ShoutSettings.resetStoredOptions(in: defaults, photoStore: store)
        #expect(!store.hasPhoto)
        #expect(defaults.object(forKey: ShoutSettings.Key.photoBackground) == nil)
    }
}

@Suite("Shout leave rule while covered")
struct ShoutCoveredLeaveTests {
    @Test func uncoveringUprightAfterLandscapeLeaves() {
        var rule = ShoutLeaveRule(startOrientation: .landscapeLeft)
        // Covered: the portrait change is recorded; the caller does not act on it.
        let leaves = rule.shouldLeave(after: .portrait)
        #expect(leaves)
        #expect(rule.leavesOnUncover(currentOrientation: .portrait))
    }

    @Test func uncoveringInLandscapeStays() {
        var rule = ShoutLeaveRule(startOrientation: .landscapeLeft)
        _ = rule.shouldLeave(after: .portrait)
        _ = rule.shouldLeave(after: .landscapeRight)
        #expect(!rule.leavesOnUncover(currentOrientation: .landscapeRight))
    }

    /// Done-key shout, phone upright the whole time: closing the sheet does not leave.
    @Test func uprightAllAlongStays() {
        let rule = ShoutLeaveRule(startOrientation: .portrait)
        #expect(!rule.leavesOnUncover(currentOrientation: .portrait))
    }

    @Test func landscapeSeenWhileCoveredCounts() {
        var rule = ShoutLeaveRule(startOrientation: .portrait)
        let first = rule.shouldLeave(after: .landscapeLeft)
        let second = rule.shouldLeave(after: .portrait)
        #expect(!first)
        #expect(second)
        #expect(rule.leavesOnUncover(currentOrientation: .portrait))
    }

    /// Through `AppNavigation`: covered, turning upright keeps the shout; uncovering leaves.
    @MainActor
    @Test func navigationHoldsTheShoutWhileCovered() {
        let navigation = AppNavigation()
        navigation.showEditing()
        navigation.deviceOrientationDidChange(.landscapeLeft)
        #expect(navigation.startShout())
        navigation.setShoutCovered(true)
        navigation.deviceOrientationDidChange(.portrait)
        #expect(navigation.isShouting, "still up under the composer")
        navigation.setShoutCovered(false)
        #expect(!navigation.isShouting, "leaves once uncovered")
    }

    @MainActor
    @Test func navigationLeavesUncoveredAsBefore() {
        let navigation = AppNavigation()
        navigation.showEditing()
        navigation.deviceOrientationDidChange(.landscapeRight)
        #expect(navigation.startShout())
        navigation.deviceOrientationDidChange(.portrait)
        #expect(!navigation.isShouting)
    }
}
