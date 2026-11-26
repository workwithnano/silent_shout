import CoreGraphics
import Foundation

/// The shout's geometry, SPEC.md sections 2.3, 6.2 and 6.3, as numbers in the original
/// 480x320 landscape reference canvas, and how that canvas sits on a real screen (PLAN
/// ruling 5: scaled uniformly to fit, centred; the background fills the whole screen).
struct ShoutCanvas: Equatable, Sendable {
    /// The original landscape screen.
    static let referenceSize = CGSize(width: 480, height: 320)

    /// Fit mode: the hidden `outputLabel` (453x302) the text is drawn into before its bitmap is
    /// stretched over the whole 480x320 canvas with a multiply blend.
    static let fitLabelSize = CGSize(width: 453, height: 302)
    /// The label's alpha in `FlipsideView.xib`, carried into its bitmap.
    static let fitTextAlpha: CGFloat = 0.894_366_2

    /// Scroll mode: one line at 180 pt, the whole marquee at alpha 0.75 (set in code; the XIB's
    /// 0.838 is overwritten), normal blending.
    static let marqueeFontSize: CGFloat = 180
    static let marqueeAlpha: CGFloat = 0.75

    /// The size of the area the shout fills, in points (the whole screen).
    let size: CGSize

    /// Points on screen per reference point.
    var scale: CGFloat {
        guard size.width > 0, size.height > 0 else { return 0 }
        return min(size.width / Self.referenceSize.width, size.height / Self.referenceSize.height)
    }

    /// The 480x320 canvas scaled to fit and centred.
    var canvasFrame: CGRect {
        let width = Self.referenceSize.width * scale
        let height = Self.referenceSize.height * scale
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    /// The label bitmap's stretch onto the canvas: 480 / 453 (= 320 / 302, so uniform).
    static var fitLabelStretch: CGFloat { referenceSize.width / fitLabelSize.width }

    /// The marquee runs across the whole screen width, like AutoScrollLabel across the whole
    /// 480 pt screen, measured in reference points so speed, gap and lead-in scale with the canvas.
    var marqueeWidth: CGFloat {
        scale > 0 ? size.width / scale : Self.referenceSize.width
    }

    /// Where an image of `imageSize` goes to fill `size` without distortion (aspect fill,
    /// centred, overflow cropped by the caller).
    static func aspectFillRect(imageSize: CGSize, in size: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: size)
        }
        let factor = max(size.width / imageSize.width, size.height / imageSize.height)
        let width = imageSize.width * factor
        let height = imageSize.height * factor
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }
}

/// The marquee's motion (SPEC.md 6.3, PLAN rulings 13 and 14), in reference points.
///
/// The text moves left at 90 pt/s. It starts with the first copy's leading edge 200 pt in from
/// the left edge, as the original's first loop did; copies follow one another with a 20 pt
/// gap, so once the first copy has reached the left edge the motion is a seamless repeat every
/// `textWidth + 20` points. The original's jump back to the start at the end of each loop is
/// not reproduced. Text no wider than the marquee does not move: one copy, centred, as
/// AutoScrollLabel did.
struct MarqueeMotion: Equatable, Sendable {
    static let speed: CGFloat = 90
    static let gap: CGFloat = 20
    static let leadIn: CGFloat = 200

    /// The width of one line of text (AutoScrollLabel's `sizeToFit` label).
    let textWidth: CGFloat
    /// The marquee's own width (`ShoutCanvas.marqueeWidth`).
    let viewWidth: CGFloat

    /// AutoScrollLabel scrolled only when the label was strictly wider than itself.
    var scrolls: Bool { textWidth > viewWidth }

    /// How far the text moves before the picture repeats.
    var wrapDistance: CGFloat { textWidth + Self.gap }

    /// The scroll view's content offset at `time` seconds: -200 at the start, growing at
    /// 90 pt/s, and wrapped into `0 ..< wrapDistance` once it has reached 0. Always 0 for text
    /// that does not scroll.
    func offset(at time: TimeInterval) -> CGFloat {
        guard scrolls else { return 0 }
        let travelled = -Self.leadIn + Self.speed * CGFloat(max(time, 0))
        guard travelled >= 0 else { return travelled }
        return travelled.truncatingRemainder(dividingBy: wrapDistance)
    }

    /// The x of each copy's leading edge at `time`, in marquee coordinates, for every copy that
    /// can be visible (two cover the marquee at any moment, because the text is wider than it).
    func copyOrigins(at time: TimeInterval) -> [CGFloat] {
        guard scrolls else { return [(viewWidth - textWidth) / 2] }
        let first = -offset(at: time)
        return [first, first + wrapDistance].filter { $0 < viewWidth }
    }
}
