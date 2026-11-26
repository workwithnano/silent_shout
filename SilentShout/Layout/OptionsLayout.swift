import CoreGraphics

/// Which option block on the Options screen, top to bottom as in `MainView.xib`.
enum OptionBlock: Int, CaseIterable, Sendable {
    /// "Writing tool", UserDefaults key `font`.
    case font = 0
    /// "Background", key `texture`.
    case texture = 1
    /// "Presentation", key `lettering`.
    case sizing = 2
}

/// Geometry of the Options screen (SPEC.md sections 2.1 and 8), computed from the safe-area
/// size so it can be unit tested at every iPhone width.
///
/// The art and the inside of each 139 pt block keep the original point sizes. What changes on
/// a taller screen is the space between blocks: the area above the button strip is cut into
/// three equal slots (one 139 pt block each in the 320x460 original) and each block is centred
/// in its slot, so the original's even vertical rhythm is kept rather than pinned to the top.
/// Horizontally, the carousel pages are as wide as the screen with the option art centred, as
/// they were 320 wide on a 320 pt screen; help bubbles keep their offset from that art.
struct OptionsLayout: Sendable {
    /// The safe-area size the screen is laid out in.
    let size: CGSize

    // Original numbers, in points (MainView.xib).
    static let originalWidth: CGFloat = 320
    static let blockHeight: CGFloat = 139
    /// The paging scroll view inside a block: y 9.5, 100 tall. (The lettering block's 9 is
    /// one of the half-point XIB accidents PLAN ruling 11 says not to reproduce.)
    static let carouselTop: CGFloat = 9.5
    static let carouselHeight: CGFloat = 100
    static let optionArtSize = CGSize(width: 200, height: 100)
    /// The page control frame (141, 98, 38, 36): its dots sit on the frame's centre line.
    static let pageDotsCenterY: CGFloat = 98 + 36 / 2
    static let buttonSize: CGFloat = 48
    /// Help at x 6, Next at x 266 (6 from the right edge) on the 320 pt screen.
    static let buttonSideInset: CGFloat = 6
    /// Both buttons end at y 455 in the 460 pt content area.
    static let buttonBottomInset: CGFloat = 5
    static let bubbleSize = CGSize(width: 103, height: 45)

    /// Height above the button strip that the three blocks share. Never less than the three
    /// blocks stacked, which is what the 460 pt original had (blocks end at 417.5, buttons start at 407).
    var blockRegionHeight: CGFloat {
        max(size.height - Self.buttonBottomInset - Self.buttonSize, Self.blockHeight * 3)
    }

    var slotHeight: CGFloat { blockRegionHeight / 3 }

    /// A block's frame in the safe area: full width, 139 tall, centred in its slot.
    func blockFrame(_ block: OptionBlock) -> CGRect {
        let y = slotHeight * CGFloat(block.rawValue) + (slotHeight - Self.blockHeight) / 2
        return CGRect(x: 0, y: y, width: size.width, height: Self.blockHeight)
    }

    /// The carousel's frame inside its block.
    var carouselFrameInBlock: CGRect {
        CGRect(x: 0, y: Self.carouselTop, width: size.width, height: Self.carouselHeight)
    }

    /// Where the current option's 200x100 art sits inside its block when the carousel rests on a page.
    var optionArtFrameInBlock: CGRect {
        CGRect(
            x: (size.width - Self.optionArtSize.width) / 2,
            y: Self.carouselTop,
            width: Self.optionArtSize.width,
            height: Self.optionArtSize.height
        )
    }

    /// The help bubble's frame inside its block. SPEC.md section 8 gives the bubbles in the
    /// 320x460 content area; converted to block coordinates and kept at the same distance from
    /// the option art they point at (the art's left edge is at x 60 on the 320 pt screen).
    func bubbleFrameInBlock(_ block: OptionBlock) -> CGRect {
        let original: CGPoint = switch block {
        case .font: CGPoint(x: 9, y: 20 - 0.5)
        case .texture: CGPoint(x: 8, y: 149 - 139.5)
        case .sizing: CGPoint(x: 8, y: 287 - 278.5)
        }
        let artLeftOnOriginal = (Self.originalWidth - Self.optionArtSize.width) / 2
        let x = optionArtFrameInBlock.minX + (original.x - artLeftOnOriginal)
        return CGRect(origin: CGPoint(x: x, y: original.y), size: Self.bubbleSize)
    }

    func bubbleFrame(_ block: OptionBlock) -> CGRect {
        bubbleFrameInBlock(block).offsetBy(dx: 0, dy: blockFrame(block).minY)
    }

    func optionArtFrame(_ block: OptionBlock) -> CGRect {
        optionArtFrameInBlock.offsetBy(dx: 0, dy: blockFrame(block).minY)
    }

    var helpButtonFrame: CGRect {
        CGRect(
            x: Self.buttonSideInset,
            y: size.height - Self.buttonBottomInset - Self.buttonSize,
            width: Self.buttonSize,
            height: Self.buttonSize
        )
    }

    var nextButtonFrame: CGRect {
        CGRect(
            x: size.width - Self.buttonSideInset - Self.buttonSize,
            y: size.height - Self.buttonBottomInset - Self.buttonSize,
            width: Self.buttonSize,
            height: Self.buttonSize
        )
    }
}

/// The carousel's page arithmetic (SPEC.md section 3).
enum CarouselPaging {
    /// The selected page for a horizontal offset: the original's
    /// `floor((offsetX - pageWidth / 2) / pageWidth) + 1`, so the choice switches when the
    /// carousel is 50% of the way to the next page, clamped to `0..<count` (PLAN ruling 10)
    /// because over-scrolling past either end would otherwise give -1 or `count`.
    static func page(forOffset offset: CGFloat, pageWidth: CGFloat, count: Int) -> Int {
        guard count > 0 else { return 0 }
        guard pageWidth > 0, offset.isFinite else { return 0 }
        let raw = Int(((offset - pageWidth / 2) / pageWidth).rounded(.down)) + 1
        return min(max(raw, 0), count - 1)
    }
}

/// The sizing options' 40-frame loops (SPEC.md section 3): 5 s per loop, forever.
enum SizingAnimation {
    static let frameCount = ShoutSizing.frameCount
    static let loopDuration = ShoutSizing.animationDuration
    static var frameInterval: Double { loopDuration / Double(frameCount) }

    /// The frame to show `elapsed` seconds after the loop started.
    static func frameIndex(elapsed: Double) -> Int {
        guard elapsed.isFinite, elapsed > 0 else { return 0 }
        let frame = Int((elapsed / frameInterval).rounded(.down))
        return frame % frameCount
    }
}
