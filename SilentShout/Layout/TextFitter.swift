import CoreGraphics
import UIKit

/// The original's fit-to-box rule (SPEC.md sections 6.1 and 6.2), shared by the Editing
/// preview and the shout.
///
/// Start at `maxSize`, step down by `step`, and stop at the first size whose word-wrapped
/// height in a box `boxWidth` wide is at most `boxHeight`. If no size fits, the result is
/// `minSize`, the last size tried. (The original loops `for (i = max; i > 10; i -= 2)` and
/// sets the font at the top of each pass, so a text that never fits keeps the size of the
/// last pass, 12, not the loop's exit value of 10.)
///
/// The numbers are points in the original reference box. Callers draw the result scaled
/// uniformly with that box (PLAN.md ruling 5).
struct TextFitter: Equatable, Sendable {
    let boxWidth: CGFloat
    let boxHeight: CGFloat
    let maxSize: CGFloat
    let minSize: CGFloat
    let step: CGFloat

    /// The Editing preview: a 300 pt wide box, fits at 206 pt or less, 200 pt down to 12 pt.
    static let preview = TextFitter(boxWidth: 300, boxHeight: 206, maxSize: 200, minSize: 12, step: 2)

    /// The shout in fit mode: a 420 pt wide box, fits at 280 pt or less, 360 pt down to 12 pt.
    static let shout = TextFitter(boxWidth: 420, boxHeight: 280, maxSize: 360, minSize: 12, step: 2)

    /// Every size the rule tries, largest first: `maxSize`, `maxSize - step`, ..., `minSize`.
    var candidateSizes: [CGFloat] {
        guard step > 0, maxSize >= minSize else { return [minSize] }
        return Array(stride(from: maxSize, through: minSize, by: -step))
    }

    /// The rule itself, with the measuring left to the caller: `heightAt(size)` is the
    /// word-wrapped height of the text at that font size in a `boxWidth` wide box.
    func fontSize(heightAt: (CGFloat) -> CGFloat) -> CGFloat {
        for size in candidateSizes where heightAt(size) <= boxHeight {
            return size
        }
        return minSize
    }

    /// The font size for `text` in the font named `fontName` (the system font if that name
    /// is not registered). Empty text gets `maxSize`: there is nothing to fit or draw.
    func fontSize(for text: String, fontName: String) -> CGFloat {
        guard !text.isEmpty else { return maxSize }
        return fontSize { size in
            let font = UIFont(name: fontName, size: size) ?? .systemFont(ofSize: size)
            return Self.wrappedHeight(of: text, font: font, width: boxWidth)
        }
    }

    /// The modern form of the original's
    /// `sizeWithFont:constrainedToSize:CGSizeMake(width, MAXFLOAT) lineBreakMode:UILineBreakModeWordWrap`:
    /// the height of the text word-wrapped to `width` (a word wider than the box breaks
    /// between characters, as UILabel does), rounded up to whole points.
    static func wrappedHeight(of text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: [.font: font, .paragraphStyle: paragraph],
            context: nil
        )
        return rect.height.rounded(.up)
    }
}
