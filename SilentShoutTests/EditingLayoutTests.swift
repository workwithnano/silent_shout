import CoreGraphics
import Testing
import UIKit
@testable import SilentShout

@Suite("Editing layout")
struct EditingLayoutTests {
    /// Safe-area sizes above the keyboard (portrait, keyboard up with its suggestion bar):
    /// iPhone SE 375x667, iPhone 13 mini 375x812, iPhone 17 Pro 402x874, iPhone 17 Pro Max
    /// 440x956, and the original 320 pt width.
    static let sizes: [CGSize] = [
        CGSize(width: 320, height: 460 - 216),
        CGSize(width: 375, height: 667 - 20 - 260),
        CGSize(width: 375, height: 812 - 50 - 291),
        CGSize(width: 402, height: 874 - 62 - 336),
        CGSize(width: 440, height: 956 - 62 - 346),
    ]

    @Test(arguments: sizes)
    func barSitsOnTheKeyboardAtFullWidth(size: CGSize) {
        let layout = EditingLayout(size: size)
        #expect(layout.barFrame == CGRect(x: 0, y: size.height - 41, width: size.width, height: 41))
    }

    @Test(arguments: sizes)
    func cardKeepsTheReferenceAspectAndFitsAboveTheBar(size: CGSize) {
        let layout = EditingLayout(size: size)
        let card = layout.cardFrame
        #expect(abs(card.width / card.height - 320.0 / 206.0) < 0.0001)
        #expect(card.minX >= 0 && card.maxX <= size.width + 0.0001)
        #expect(card.minY >= 0)
        #expect(card.maxY <= layout.barFrame.minY + 0.0001)
        // Centred in the space above the bar.
        #expect(abs(card.minY - (layout.barFrame.minY - card.maxY)) < 0.0001)
        #expect(abs(card.midX - size.width / 2) < 0.0001)
    }

    @Test(arguments: sizes.dropFirst())
    func cardSpansTheWidthOnCurrentPhones(size: CGSize) {
        let layout = EditingLayout(size: size)
        #expect(layout.cardScale == size.width / 320)
        #expect(layout.cardFrame.width == size.width)
    }

    @Test func originalWidthIsTheReferenceBoxAtScaleOne() {
        // 460 - 216 - 41 = 203 pt above the bar is 3 pt short of 206, so the card shrinks a touch.
        let short = EditingLayout(size: CGSize(width: 320, height: 460 - 216))
        #expect(abs(short.cardScale - CGFloat(203) / CGFloat(206)) < 1e-9)
        let roomy = EditingLayout(size: CGSize(width: 320, height: 300))
        #expect(roomy.cardScale == 1)
        #expect(roomy.labelFrameInCard == CGRect(x: 10, y: 0, width: 300, height: 206))
        #expect(roomy.previewArtFrameInCard == CGRect(x: 0, y: -20, width: 320, height: 226))
    }

    @Test(arguments: sizes)
    func labelAndArtScaleWithTheCard(size: CGSize) {
        let layout = EditingLayout(size: size)
        let scale = layout.cardScale
        let label = layout.labelFrameInCard
        #expect(abs(label.width - 300 * scale) < 0.0001)
        #expect(abs(label.height - layout.cardFrame.height) < 0.0001)
        #expect(abs(label.minX - 10 * scale) < 0.0001)
        let art = layout.previewArtFrameInCard
        // The art's bottom edge is the card's bottom edge; its top 20 pt are cut off.
        #expect(abs(art.maxY - layout.cardFrame.height) < 0.0001)
        #expect(abs(art.width - layout.cardFrame.width) < 0.0001)
    }

    @Test(arguments: sizes)
    func barControlsKeepOriginalSizesAndStretchTheField(size: CGSize) {
        let layout = EditingLayout(size: size)
        let back = layout.backButtonFrameInBar
        #expect(back.width >= 44 && back.height >= 44)
        #expect(back.midX == EditingLayout.backArtFrame.midX)
        #expect(back.midY == EditingLayout.backArtFrame.midY)
        #expect(back.minX >= 0)

        let background = layout.fieldBackgroundFrameInBar
        #expect(background.minX == 46 && background.minY == 6 && background.height == 28)
        #expect(background.maxX == size.width - 12)
        #expect(background.minX >= back.maxX)

        let field = layout.textFieldFrameInBar
        #expect(field.minX == 53 && field.height == 28)
        #expect(field.maxX == size.width - 13)
        #expect(background.contains(field))
    }

    @Test func degenerateSizesDoNotGoNegative() {
        let layout = EditingLayout(size: CGSize(width: 0, height: 0))
        #expect(layout.cardScale == 0)
        #expect(layout.barFrame.minY == 0)
        #expect(layout.textFieldFrameInBar.width == 0)
    }
}

@Suite("App navigation")
@MainActor
struct AppNavigationTests {
    @Test func shoutStartsOnlyFromEditingAndOnlyOnce() {
        let navigation = AppNavigation()
        #expect(navigation.startShout() == false, "not from Options")
        #expect(navigation.isShouting == false)

        navigation.showEditing()
        #expect(navigation.startShout() == true)
        #expect(navigation.isShouting)
        #expect(navigation.startShout() == false, "a second Done or rotation does not start another")

        navigation.endShout()
        #expect(navigation.isShouting == false)
        #expect(navigation.isShowingEditing, "ending the shout returns to Editing")
        #expect(navigation.startShout() == true, "and it can start again")
    }

    @Test func noNewShoutWhileTheLastOneIsStillDissolvingAway() {
        let navigation = AppNavigation()
        navigation.showEditing()
        navigation.startShout()
        navigation.shoutPresentationDidChange(onScreen: true)
        navigation.endShout()
        #expect(navigation.isShoutOnScreen, "still on screen until the dismissal completes")
        #expect(navigation.startShout() == false)
        navigation.shoutPresentationDidChange(onScreen: false)
        #expect(navigation.startShout() == true)
    }

    @Test func recordsDeviceOrientation() {
        let navigation = AppNavigation()
        #expect(navigation.deviceOrientation == .unknown)
        navigation.deviceOrientationDidChange(.landscapeLeft)
        #expect(navigation.deviceOrientation == .landscapeLeft)
    }

    @Test func onlyLandscapeStartsTheShout() {
        #expect(ShoutOrientationRule.startsShout(.landscapeLeft))
        #expect(ShoutOrientationRule.startsShout(.landscapeRight))
        for orientation: UIDeviceOrientation in [.portrait, .portraitUpsideDown, .faceUp, .faceDown, .unknown] {
            #expect(!ShoutOrientationRule.startsShout(orientation))
        }
        #expect(ShoutOrientationRule.leavesShout(.portrait))
        for orientation: UIDeviceOrientation in [.landscapeLeft, .landscapeRight, .portraitUpsideDown, .faceUp, .faceDown, .unknown] {
            #expect(!ShoutOrientationRule.leavesShout(orientation))
        }
    }
}
