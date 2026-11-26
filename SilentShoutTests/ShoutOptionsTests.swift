import Testing
import UIKit
@testable import SilentShout

@Suite("Shout options")
struct ShoutOptionsTests {
    // MARK: Fonts

    @Test func fontsMatchTheThreeOptions101Offers() {
        #expect(ShoutFont.allCases == [.pencil, .dryErase, .keyboard])
        #expect(ShoutFont.allCases.map(\.rawValue) == [0, 1, 2])
    }

    @Test func fontNames() {
        #expect(ShoutFont.pencil.fontName == "lateron")
        #expect(ShoutFont.dryErase.fontName == "Kristi")
        #expect(ShoutFont.keyboard.fontName == "Helvetica")
        #expect(ShoutFont.pencil.fileName == "later_on.ttf")
        #expect(ShoutFont.dryErase.fileName == "Kristi.ttf")
        #expect(ShoutFont.keyboard.fileName == nil)
    }

    @Test func inkColours() {
        #expect(ShoutFont.pencil.ink.rgb == 0x000000)
        #expect(ShoutFont.dryErase.ink.rgb == 0xE93232)
        #expect(ShoutFont.keyboard.ink.rgb == 0x000000)
    }

    @Test func inkComponents() {
        let ink = ShoutFont.dryErase.ink
        #expect(ink.red == 233.0 / 255)
        #expect(ink.green == 50.0 / 255)
        #expect(ink.blue == 50.0 / 255)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(ink.uiColor.getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(abs(r - 233.0 / 255) < 0.001)
        #expect(abs(g - 50.0 / 255) < 0.001)
        #expect(abs(b - 50.0 / 255) < 0.001)
        #expect(a == 1)
    }

    @Test func fontCarouselImages() {
        #expect(ShoutFont.allCases.map(\.carouselImageName)
            == ["icon-lettering_pencil", "icon-lettering_reddryerase", "icon-lettering_keyboard"])
    }

    @Test(arguments: [(-1, ShoutFont.pencil), (0, .pencil), (1, .dryErase), (2, .keyboard),
                      (3, .keyboard), (5, .keyboard), (Int.max, .keyboard), (Int.min, .pencil)])
    func fontClamping(stored: Int, expected: ShoutFont) {
        #expect(ShoutFont.clamped(stored) == expected)
    }

    // MARK: Textures

    @Test func texturesMatchTheThreeOptions101Offers() {
        #expect(ShoutTexture.allCases == [.notecard, .whiteboard, .cardboard])
        #expect(ShoutTexture.allCases.map(\.rawValue) == [0, 1, 2])
    }

    @Test func textureImageNames() {
        #expect(ShoutTexture.allCases.map(\.shoutImageName)
            == ["bkgrd_texture-notecards", "bkgrd_texture-whiteboard", "bkgrd_texture-cardboard"])
        #expect(ShoutTexture.allCases.map(\.previewImageName)
            == ["bkgrd_texture-previewnotecard", "bkgrd_texture-previewwhiteboard", "bkgrd_texture-previewcardboard"])
        #expect(ShoutTexture.allCases.map(\.carouselImageName)
            == ["icon-texture_notecard", "icon-texture_whiteboard", "icon-texture_cardboard"])
        #expect(ShoutTexture.cameraCarouselImageName == "icon-texture_camera")
    }

    @Test(arguments: [(-1, ShoutTexture.notecard), (0, .notecard), (1, .whiteboard), (2, .cardboard),
                      (3, .cardboard), (Int.max, .cardboard)])
    func textureClamping(stored: Int, expected: ShoutTexture) {
        #expect(ShoutTexture.clamped(stored) == expected)
    }

    // MARK: Sizing

    @Test func sizingMatchesTheTwoOptions101Offers() {
        #expect(ShoutSizing.allCases == [.scaleToFit, .scroll])
        #expect(ShoutSizing.allCases.map(\.rawValue) == [0, 1])
    }

    @Test func sizingAnimationFrames() {
        #expect(ShoutSizing.frameCount == 40)
        #expect(ShoutSizing.animationDuration == 5.0)
        let scale = ShoutSizing.scaleToFit.frameImageNames
        #expect(scale.count == 40)
        #expect(scale.first == "scale_00000")
        #expect(scale.last == "scale_00039")
        let scroll = ShoutSizing.scroll.frameImageNames
        #expect(scroll.count == 40)
        #expect(scroll.first == "Scroll-Your-Note_00000")
        #expect(scroll.last == "Scroll-Your-Note_00039")
    }

    /// Index 2 ("swipe") is not offered; a stored 2 clamps to the marquee it shared code with.
    @Test(arguments: [(-1, ShoutSizing.scaleToFit), (0, .scaleToFit), (1, .scroll), (2, .scroll), (99, .scroll)])
    func sizingClamping(stored: Int, expected: ShoutSizing) {
        #expect(ShoutSizing.clamped(stored) == expected)
    }
}
