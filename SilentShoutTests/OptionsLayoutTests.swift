import CoreGraphics
import Foundation
import Testing
@testable import SilentShout

@Suite("Carousel paging")
struct CarouselPagingTests {
    @Test(arguments: [
        // (offset, expected page) for 3 pages of 320
        (CGFloat(0), 0),
        (159, 0),
        (160, 1), // switches at 50% of the way
        (320, 1),
        (479, 1),
        (480, 2),
        (640, 2),
    ])
    func switchesHalfwayAcross(offset: CGFloat, expected: Int) {
        #expect(CarouselPaging.page(forOffset: offset, pageWidth: 320, count: 3) == expected)
    }

    @Test func clampsWhileOverscrolling() {
        // The original could store -1 (bouncing past the first page) or `count` (past the last).
        #expect(CarouselPaging.page(forOffset: -200, pageWidth: 320, count: 3) == 0)
        #expect(CarouselPaging.page(forOffset: 800, pageWidth: 320, count: 3) == 2)
        #expect(CarouselPaging.page(forOffset: 10_000, pageWidth: 402, count: 2) == 1)
    }

    @Test func worksAtAnyPageWidth() {
        #expect(CarouselPaging.page(forOffset: 200, pageWidth: 402, count: 3) == 0)
        #expect(CarouselPaging.page(forOffset: 201, pageWidth: 402, count: 3) == 1)
        #expect(CarouselPaging.page(forOffset: 660, pageWidth: 440, count: 3) == 2)
    }

    @Test func degenerateInputs() {
        #expect(CarouselPaging.page(forOffset: 100, pageWidth: 0, count: 3) == 0)
        #expect(CarouselPaging.page(forOffset: .nan, pageWidth: 320, count: 3) == 0)
        #expect(CarouselPaging.page(forOffset: 100, pageWidth: 320, count: 0) == 0)
    }
}

@Suite("Sizing animation")
struct SizingAnimationTests {
    @Test func fortyFramesInFiveSeconds() {
        #expect(SizingAnimation.frameInterval == 0.125)
        #expect(SizingAnimation.frameIndex(elapsed: 0) == 0)
        #expect(SizingAnimation.frameIndex(elapsed: 0.124) == 0)
        #expect(SizingAnimation.frameIndex(elapsed: 0.125) == 1)
        #expect(SizingAnimation.frameIndex(elapsed: 4.99) == 39)
    }

    @Test func loopsForever() {
        #expect(SizingAnimation.frameIndex(elapsed: 5.0) == 0)
        #expect(SizingAnimation.frameIndex(elapsed: 12.5) == 20)
        #expect(SizingAnimation.frameIndex(elapsed: 3600.06) == 0)
        #expect(SizingAnimation.frameIndex(elapsed: -1) == 0)
    }
}

@Suite("Options layout")
struct OptionsLayoutTests {
    /// Safe-area sizes in portrait: the original 320x460, an SE-class 375 pt phone
    /// (667 tall, 20 pt status bar), iPhone 17e-class 390x844 (47/34 insets),
    /// iPhone 17 Pro 402x874 (62/34) and a Pro Max-class 440x956 (62/34).
    static let sizes: [CGSize] = [
        CGSize(width: 320, height: 460),
        CGSize(width: 375, height: 647),
        CGSize(width: 390, height: 763),
        CGSize(width: 402, height: 778),
        CGSize(width: 440, height: 860),
    ]

    @Test func reproducesTheOriginalOn320x460() {
        let layout = OptionsLayout(size: CGSize(width: 320, height: 460))
        #expect(layout.blockFrame(.font) == CGRect(x: 0, y: 0, width: 320, height: 139))
        #expect(layout.blockFrame(.texture) == CGRect(x: 0, y: 139, width: 320, height: 139))
        #expect(layout.blockFrame(.sizing) == CGRect(x: 0, y: 278, width: 320, height: 139))
        #expect(layout.optionArtFrame(.font) == CGRect(x: 60, y: 9.5, width: 200, height: 100))
        #expect(layout.helpButtonFrame == CGRect(x: 6, y: 407, width: 48, height: 48))
        #expect(layout.nextButtonFrame == CGRect(x: 266, y: 407, width: 48, height: 48))
        // SPEC.md section 8 bubble frames, less the half point the blocks lose here.
        #expect(layout.bubbleFrame(.font) == CGRect(x: 9, y: 19.5, width: 103, height: 45))
        #expect(layout.bubbleFrame(.texture) == CGRect(x: 8, y: 148.5, width: 103, height: 45))
        #expect(layout.bubbleFrame(.sizing) == CGRect(x: 8, y: 286.5, width: 103, height: 45))
    }

    @Test(arguments: sizes)
    func everythingFitsInsideTheSafeArea(size: CGSize) {
        let layout = OptionsLayout(size: size)
        let bounds = CGRect(origin: .zero, size: size)
        var frames = [layout.helpButtonFrame, layout.nextButtonFrame]
        for block in OptionBlock.allCases {
            frames += [layout.blockFrame(block), layout.bubbleFrame(block), layout.optionArtFrame(block)]
        }
        for frame in frames {
            #expect(bounds.contains(frame), "\(frame) leaves \(bounds)")
        }
    }

    @Test(arguments: sizes)
    func nothingOverlaps(size: CGSize) {
        let layout = OptionsLayout(size: size)
        let blocks = OptionBlock.allCases.map(layout.blockFrame)
        // Blocks are stacked without overlap, in order.
        for (upper, lower) in zip(blocks, blocks.dropFirst()) {
            #expect(upper.maxY <= lower.minY)
        }
        // The buttons sit below the last block and apart from each other.
        #expect(blocks[2].maxY <= layout.helpButtonFrame.minY + 10.5,
                "the original lets the last block's empty bottom 10.5 pt run behind the buttons")
        #expect(layout.optionArtFrame(.sizing).maxY + 15 <= layout.helpButtonFrame.minY)
        let lastDotsBottom = blocks[2].minY + OptionsLayout.pageDotsCenterY + 3.25
        #expect(lastDotsBottom <= layout.helpButtonFrame.minY)
        #expect(!layout.helpButtonFrame.intersects(layout.nextButtonFrame))
        // Each bubble stays inside its own block and clear of the other blocks' art.
        for block in OptionBlock.allCases {
            let bubble = layout.bubbleFrame(block)
            #expect(layout.blockFrame(block).contains(bubble))
            for other in OptionBlock.allCases where other != block {
                #expect(!bubble.intersects(layout.optionArtFrame(other)))
            }
        }
    }

    @Test(arguments: sizes)
    func bubblesKeepTheirOffsetFromTheArt(size: CGSize) {
        let layout = OptionsLayout(size: size)
        #expect(layout.optionArtFrame(.font).minX - layout.bubbleFrame(.font).minX == 51)
        #expect(layout.optionArtFrame(.texture).minX - layout.bubbleFrame(.texture).minX == 52)
        #expect(layout.optionArtFrame(.font).midX == size.width / 2)
    }

    @Test(arguments: sizes)
    func buttonsAreAtLeast44Points(size: CGSize) {
        let layout = OptionsLayout(size: size)
        #expect(layout.helpButtonFrame.width >= 44 && layout.helpButtonFrame.height >= 44)
        #expect(layout.nextButtonFrame.maxX == size.width - 6)
        #expect(layout.nextButtonFrame.maxY == size.height - 5)
    }

    @Test func blocksSpreadEvenlyOnTallScreens() {
        let layout = OptionsLayout(size: CGSize(width: 402, height: 778))
        let tops = OptionBlock.allCases.map { layout.blockFrame($0).minY }
        #expect(abs((tops[1] - tops[0]) - (tops[2] - tops[1])) < 0.001)
        #expect(tops[0] > 0)
    }
}

@Suite("Settings reset for UI tests")
@MainActor
struct SettingsResetTests {
    @Test func resetRemovesEveryStoredKey() throws {
        let defaults = try #require(UserDefaults(suiteName: "SettingsResetTests"))
        defaults.removePersistentDomain(forName: "SettingsResetTests")
        let settings = ShoutSettings(defaults: defaults)
        settings.text = "hello"
        settings.font = .keyboard
        settings.texture = .cardboard
        settings.sizing = .scroll
        ShoutSettings.resetStoredOptions(in: defaults)
        let fresh = ShoutSettings(defaults: defaults)
        #expect(fresh.text == nil)
        #expect(fresh.font == .pencil)
        #expect(fresh.texture == .notecard)
        #expect(fresh.sizing == .scaleToFit)
    }
}
