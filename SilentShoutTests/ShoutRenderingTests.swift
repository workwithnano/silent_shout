import CoreGraphics
import Testing
import UIKit
@testable import SilentShout

@Suite("Shout canvas and marquee")
struct ShoutLayoutTests {
    // MARK: Canvas (PLAN ruling 5)

    @Test func referenceScreenIsScaleOne() {
        let canvas = ShoutCanvas(size: CGSize(width: 480, height: 320))
        #expect(canvas.scale == 1)
        #expect(canvas.canvasFrame == CGRect(x: 0, y: 0, width: 480, height: 320))
        #expect(canvas.marqueeWidth == 480)
    }

    /// iPhone 17 Pro in landscape: the height limits, the canvas is centred horizontally.
    @Test func wideScreenFitsByHeightAndCentres() {
        let canvas = ShoutCanvas(size: CGSize(width: 874, height: 402))
        #expect(abs(canvas.scale - 402.0 / 320.0) < 1e-9)
        let frame = canvas.canvasFrame
        #expect(abs(frame.height - 402) < 1e-9)
        #expect(abs(frame.width - 603) < 1e-9)
        #expect(abs(frame.midX - 437) < 1e-9)
        #expect(abs(canvas.marqueeWidth - 874 / canvas.scale) < 1e-9)
    }

    @Test func emptySizeHasNoScale() {
        #expect(ShoutCanvas(size: .zero).scale == 0)
    }

    @Test func fitLabelStretchIsUniform() {
        #expect(abs(ShoutCanvas.fitLabelStretch - 320.0 / 302.0) < 0.001)
    }

    @Test func aspectFillCoversWithoutDistortion() {
        let rect = ShoutCanvas.aspectFillRect(imageSize: CGSize(width: 480, height: 320), in: CGSize(width: 874, height: 402))
        #expect(rect.width >= 874 && rect.height >= 402)
        #expect(abs(rect.width / rect.height - 1.5) < 1e-9)
        #expect(abs(rect.midX - 437) < 1e-9)
        #expect(abs(rect.midY - 201) < 1e-9)
    }

    // MARK: Marquee (SPEC 6.3, rulings 13 and 14)

    @Test func marqueeStartsTwoHundredInAndMovesAtNinety() {
        let motion = MarqueeMotion(textWidth: 1000, viewWidth: 480)
        #expect(motion.scrolls)
        #expect(motion.offset(at: 0) == -200)
        #expect(motion.offset(at: 1) == -110)
        #expect(abs(motion.offset(at: 200.0 / 90.0)) < 1e-9)
        // The first copy's leading edge is 200 pt in from the left at the start.
        #expect(motion.copyOrigins(at: 0) == [200])
    }

    @Test func marqueeWrapsEveryTextWidthPlusGap() {
        let motion = MarqueeMotion(textWidth: 1000, viewWidth: 480)
        #expect(motion.wrapDistance == 1020)
        let leadIn = 200.0 / 90.0
        let period = 1020.0 / 90.0
        for t in [0.5, 3.0, 7.25] {
            let a = motion.offset(at: leadIn + t)
            let b = motion.offset(at: leadIn + t + period)
            #expect(abs(a - b) < 1e-6, "same picture one period later")
        }
        // Smooth across the wrap: just before and just after differ by one frame's travel.
        let before = motion.offset(at: leadIn + period - 0.001)
        let after = motion.offset(at: leadIn + period + 0.001)
        #expect(before > 1019 && after < 1)
        // The copy that was second is then exactly where the first copy was.
        #expect(abs(motion.copyOrigins(at: leadIn + period - 0.001)[1] - motion.copyOrigins(at: leadIn + period + 0.001)[0]) < 0.2)
    }

    @Test func marqueeOffsetsStayInRangeOnceRunning() {
        let motion = MarqueeMotion(textWidth: 750, viewWidth: 480)
        for step in 0..<2000 {
            let t = 200.0 / 90.0 + Double(step) * 0.037
            let offset = motion.offset(at: t)
            #expect(offset >= 0 && offset < motion.wrapDistance)
            let origins = motion.copyOrigins(at: t)
            // The copies always cover the whole marquee: the first starts at or before the left
            // edge, and a second is listed whenever the first and its gap end inside it.
            #expect(origins[0] <= 0)
            #expect(origins[0] + motion.wrapDistance >= 480 || origins.count == 2)
            if origins.count == 2 { #expect(origins[1] - origins[0] == motion.wrapDistance) }
        }
    }

    @Test func textNoWiderThanTheMarqueeIsCentredAndStill() {
        let motion = MarqueeMotion(textWidth: 300, viewWidth: 480)
        #expect(!motion.scrolls)
        #expect(motion.offset(at: 5) == 0)
        #expect(motion.copyOrigins(at: 0) == [90])
        #expect(motion.copyOrigins(at: 12.5) == [90])
        // Exactly as wide does not scroll either (AutoScrollLabel tested `>`).
        #expect(!MarqueeMotion(textWidth: 480, viewWidth: 480).scrolls)
        #expect(MarqueeMotion(textWidth: 481, viewWidth: 480).scrolls)
    }

    @Test func negativeTimeIsTheStart() {
        let motion = MarqueeMotion(textWidth: 1000, viewWidth: 480)
        #expect(motion.offset(at: -3) == -200)
    }
}

@Suite("Leaving the shout by turning the phone upright")
struct ShoutLeaveRuleTests {
    /// Feeds `changes` to a rule started at `start`; one answer per change.
    private func answers(start: UIDeviceOrientation, _ changes: [UIDeviceOrientation]) -> [Bool] {
        var rule = ShoutLeaveRule(startOrientation: start)
        var result: [Bool] = []
        for change in changes { result.append(rule.shouldLeave(after: change)) }
        return result
    }

    @Test func startedInLandscapeLeavesOnPortrait() {
        #expect(answers(start: .landscapeLeft, [.portrait]) == [true])
    }

    @Test func flippingBetweenLandscapesDoesNotLeave() {
        #expect(answers(start: .landscapeRight, [.landscapeLeft, .landscapeRight, .portrait]) == [false, false, true])
    }

    /// The Done key with the phone upright: portrait must not leave until the phone has been
    /// on its side.
    @Test func startedUprightWaitsForLandscapeFirst() {
        #expect(!ShoutLeaveRule(startOrientation: .portrait).hasBeenLandscape)
        #expect(answers(start: .portrait, [.portrait, .faceUp, .portrait, .landscapeLeft, .portrait])
            == [false, false, false, false, true])
    }

    @Test func otherOrientationsNeverLeaveNorReset() {
        for start in [UIDeviceOrientation.unknown, .faceUp, .faceDown, .portraitUpsideDown] {
            #expect(answers(start: start, [.portrait]) == [false], "started \(start.rawValue)")
        }
        #expect(answers(start: .landscapeLeft, [.faceUp, .faceDown, .portraitUpsideDown, .unknown, .portrait])
            == [false, false, false, false, true], "landscape is still remembered")
    }

    @Test func presentationOrientationIsUprightForTheHeldLandscape() {
        #expect(ShoutOrientationRule.presentationOrientation(for: .landscapeLeft) == .landscapeRight)
        #expect(ShoutOrientationRule.presentationOrientation(for: .landscapeRight) == .landscapeLeft)
        // Done key with the phone upright: landscape right, as the original forced it.
        #expect(ShoutOrientationRule.presentationOrientation(for: .portrait) == .landscapeRight)
        #expect(ShoutOrientationRule.presentationOrientation(for: .faceUp) == .landscapeRight)
    }
}

@Suite("Shout navigation")
@MainActor
struct ShoutNavigationTests {
    private func editingNavigation(orientation: UIDeviceOrientation) -> AppNavigation {
        let navigation = AppNavigation()
        navigation.showEditing()
        navigation.deviceOrientationDidChange(orientation)
        return navigation
    }

    @Test func turningUprightAfterARotationStartLeaves() {
        let navigation = editingNavigation(orientation: .landscapeLeft)
        #expect(navigation.startShout())
        navigation.deviceOrientationDidChange(.landscapeRight)
        #expect(navigation.isShouting)
        navigation.deviceOrientationDidChange(.portrait)
        #expect(!navigation.isShouting)
        #expect(navigation.path == [.editing])
    }

    @Test func doneKeyShoutStaysUpWhileThePhoneIsUpright() {
        let navigation = editingNavigation(orientation: .portrait)
        #expect(navigation.startShout())
        navigation.deviceOrientationDidChange(.faceUp)
        navigation.deviceOrientationDidChange(.portrait)
        #expect(navigation.isShouting)
        navigation.deviceOrientationDidChange(.landscapeLeft)
        navigation.deviceOrientationDidChange(.portrait)
        #expect(!navigation.isShouting)
    }

    @Test func eachShoutStartsTheRuleAfresh() {
        let navigation = editingNavigation(orientation: .landscapeLeft)
        navigation.startShout()
        navigation.endShout()
        navigation.shoutPresentationDidChange(onScreen: false)
        navigation.deviceOrientationDidChange(.portrait)
        #expect(navigation.startShout(), "Done key, upright")
        navigation.deviceOrientationDidChange(.faceDown)
        navigation.deviceOrientationDidChange(.portrait)
        #expect(navigation.isShouting, "landscape from the previous shout is not remembered")
    }

    @Test func doubleBackPopsToOptionsOnceTheShoutHasGone() {
        let navigation = editingNavigation(orientation: .portrait)
        navigation.startShout()
        navigation.shoutPresentationDidChange(onScreen: true)
        navigation.endShout(returningToOptions: true)
        #expect(!navigation.isShouting)
        #expect(navigation.isReturningToOptions)
        #expect(navigation.path == [.editing], "Editing stays until the dissolve has finished")
        navigation.shoutPresentationDidChange(onScreen: false)
        #expect(navigation.path.isEmpty)
        // Editing keeps the keyboard down until it is shown again.
        #expect(navigation.isReturningToOptions)
        navigation.showEditing()
        #expect(!navigation.isReturningToOptions)
    }

    @Test func backStaysOnEditing() {
        let navigation = editingNavigation(orientation: .portrait)
        navigation.startShout()
        navigation.shoutPresentationDidChange(onScreen: true)
        navigation.endShout()
        navigation.shoutPresentationDidChange(onScreen: false)
        #expect(navigation.path == [.editing])
        #expect(!navigation.isReturningToOptions)
        #expect(!navigation.isShoutOnScreen)
    }

    @Test func endingWhenNotShoutingDoesNothing() {
        let navigation = editingNavigation(orientation: .portrait)
        navigation.endShout(returningToOptions: true)
        #expect(!navigation.isReturningToOptions)
        #expect(navigation.path == [.editing])
    }
}

@Suite("Shout renderer")
@MainActor
struct ShoutRendererTests {
    static let screen = CGSize(width: 874, height: 402)

    private func scene(_ text: String, sizing: ShoutSizing, font: ShoutFont = .pencil, texture: ShoutTexture = .notecard) -> ShoutScene {
        ShoutScene(text: text, font: font, sizing: sizing, background: .texture(texture))
    }

    @Test(arguments: ShoutSizing.allCases)
    func imageHasTheRequestedSize(sizing: ShoutSizing) {
        let image = ShoutRenderer.image(of: scene("Hello there, this is a long enough line to scroll", sizing: sizing), size: Self.screen, scale: 2)
        #expect(image.size == Self.screen)
        #expect(image.scale == 2)
        #expect(image.cgImage?.width == 1748)
        #expect(image.cgImage?.height == 804)
    }

    @Test(arguments: ShoutSizing.allCases)
    func referenceSizeImage(sizing: ShoutSizing) {
        let image = ShoutRenderer.image(of: scene("Hi Mom!", sizing: sizing), size: ShoutCanvas.referenceSize, scale: 1)
        #expect(image.size == CGSize(width: 480, height: 320))
    }

    @Test(arguments: ShoutSizing.allCases)
    func textChangesThePicture(sizing: ShoutSizing) throws {
        let plain = ShoutRenderer.image(of: scene("Hello", sizing: sizing), size: Self.screen, scale: 1, content: .backgroundOnly)
        let shout = ShoutRenderer.image(of: scene("Hello", sizing: sizing), size: Self.screen, scale: 1)
        #expect(try darkestLuma(plain) > darkestLuma(shout) + 40)
    }

    /// Fit mode multiplies the ink onto the background at the label's alpha: black ink on white
    /// leaves 1 - 0.894 of the white.
    @Test func fitTextIsMultipliedAtTheLabelsAlpha() throws {
        let white = UIGraphicsImageRenderer(size: CGSize(width: 48, height: 32)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 48, height: 32))
        }
        let scene = ShoutScene(text: "I", font: .keyboard, sizing: .scaleToFit, background: ShoutBackground(id: "white", image: white))
        let image = ShoutRenderer.image(of: scene, size: ShoutCanvas.referenceSize, scale: 1)
        let darkest = try darkestLuma(image)
        let expected = (1 - ShoutCanvas.fitTextAlpha) * 255
        #expect(abs(Double(darkest) - expected) <= 3, "darkest \(darkest), expected about \(expected)")

        // Red ink on mid grey comes out darker than both: multiply, not normal blending.
        let grey = UIGraphicsImageRenderer(size: CGSize(width: 48, height: 32)).image { context in
            UIColor(white: 0.5, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 48, height: 32))
        }
        // Dry-erase ink is #E93232: normal blending would leave the red channel near 222.
        let redScene = ShoutScene(text: "I", font: .dryErase, sizing: .scaleToFit, background: ShoutBackground(id: "grey", image: grey))
        let pixel = try darkestPixel(ShoutRenderer.image(of: redScene, size: ShoutCanvas.referenceSize, scale: 1))
        #expect(pixel.red < 0.5 * 255 * 0.95, "red channel darkened by the multiply: \(pixel)")
        #expect(pixel.green < 0.5 * 255 * 0.4)
    }

    @Test func emptyTextDrawsOnlyTheBackground() throws {
        for sizing in ShoutSizing.allCases {
            let plain = ShoutRenderer.image(of: scene("", sizing: sizing), size: Self.screen, scale: 1, content: .backgroundOnly)
            let shout = ShoutRenderer.image(of: scene("", sizing: sizing), size: Self.screen, scale: 1)
            #expect(try darkestLuma(plain) == darkestLuma(shout))
        }
    }

    @Test func backgroundIsAValue() {
        let texture = ShoutBackground.texture(.cardboard)
        #expect(texture == .texture(.cardboard))
        #expect(texture != .texture(.notecard))
        #expect(texture.image.size == CGSize(width: 480, height: 320))
        // Equality is by id alone, so the shout's image cache redraws exactly when the id changes.
        let photo = ShoutBackground(id: "photo-1", image: UIImage())
        #expect(photo == ShoutBackground(id: "photo-1", image: UIImage()))
        #expect(photo != ShoutBackground(id: "photo-2", image: photo.image))
    }

    @Test func marqueeMotionUsesTheLineWidthAt180() {
        let canvas = ShoutCanvas(size: ShoutCanvas.referenceSize)
        let short = ShoutRenderer.marqueeMotion(for: "Hi", font: .keyboard, canvas: canvas)
        #expect(!short.scrolls)
        let long = ShoutRenderer.marqueeMotion(for: "Can you pick up milk on the way home?", font: .keyboard, canvas: canvas)
        #expect(long.scrolls)
        #expect(long.textWidth > 2000)
        #expect(ShoutRenderer.marqueeMotion(for: "", font: .keyboard, canvas: canvas).textWidth == 0)
    }

    // MARK: Pixels

    private struct Pixel: CustomStringConvertible {
        let red: Double, green: Double, blue: Double
        var luma: Double { 0.299 * red + 0.587 * green + 0.114 * blue }
        var description: String { "(\(Int(red)), \(Int(green)), \(Int(blue)))" }
    }

    private func darkestLuma(_ image: UIImage) throws -> Int {
        Int(try darkestPixel(image).luma.rounded())
    }

    private func darkestPixel(_ image: UIImage) throws -> Pixel {
        let cgImage = try #require(image.cgImage)
        let width = cgImage.width, height = cgImage.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        var darkest = Pixel(red: 255, green: 255, blue: 255)
        for i in stride(from: 0, to: bytes.count, by: 4) {
            let pixel = Pixel(red: Double(bytes[i]), green: Double(bytes[i + 1]), blue: Double(bytes[i + 2]))
            if pixel.luma < darkest.luma { darkest = pixel }
        }
        return darkest
    }
}
