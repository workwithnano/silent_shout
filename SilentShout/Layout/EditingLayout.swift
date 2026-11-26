import CoreGraphics

/// Geometry of the Editing screen (SPEC.md section 2.2), computed from the safe-area size
/// above the keyboard so it can be unit tested at every iPhone width.
///
/// The text bar keeps its original 41 pt height and its art at original point sizes, pinned
/// to the bottom of that area, so it sits directly on the keyboard; on wider screens the bar
/// art tiles and the field's rounded background stretches between its end caps.
///
/// The preview card is what the original showed of the preview: the lower 320x206 pt of the
/// 320x226 texture art (its top 20 pt sat under the opaque black status bar, and the art has
/// a dark band there for that reason), with the 300x206 label box inside it at x 10. Per PLAN
/// ruling 5 that reference box is scaled uniformly to the screen width, or less if the height
/// above the bar is short, and centred in the space between the safe-area top and the bar.
struct EditingLayout: Sendable {
    /// The safe-area size, which ends at the top of the keyboard while it is up.
    let size: CGSize

    // Original numbers, in points (PreviewView.xib).
    static let barHeight: CGFloat = 41
    /// The back button's art frame in the bar: 33x33 art at (5.5, 3.5).
    static let backArtFrame = CGRect(x: 5.5, y: 3.5, width: 33, height: 33)
    /// Tap targets are at least 44 pt (PLAN ruling 7).
    static let minimumTapSize: CGFloat = 44
    /// `textfield.png` sits at (46, 6), 28 tall, ending 12 pt from the bar's right edge.
    static let fieldBackgroundLeft: CGFloat = 46
    static let fieldBackgroundRightInset: CGFloat = 12
    static let fieldTop: CGFloat = 6
    static let fieldHeight: CGFloat = 28
    /// The rounded ends of `textfield.png` (272x28 art), which are never stretched.
    static let fieldCapInset: CGFloat = 14
    /// The text field itself at x 53, ending 13 pt from the right edge. The XIB made it 31 tall,
    /// 3 pt taller than its background; ruling 11 says not to reproduce that, so it is 28.
    static let textFieldLeft: CGFloat = 53
    static let textFieldRightInset: CGFloat = 13

    /// The preview texture art (320x226 pt) and the part of it the original showed.
    static let previewArtSize = CGSize(width: 320, height: 226)
    static let previewHiddenTop: CGFloat = 20
    static let cardReferenceSize = CGSize(width: 320, height: 206)
    /// The 300x206 preview label inside the card's reference box (it was at (10, 20) in the
    /// full 226 pt art). This is `TextFitter.preview`'s box.
    static let labelFrameInReference = CGRect(x: 10, y: 0, width: 300, height: 206)

    var barFrame: CGRect {
        CGRect(x: 0, y: max(size.height - Self.barHeight, 0), width: size.width, height: Self.barHeight)
    }

    /// The space the card is centred in: from the safe-area top to the top of the bar.
    var cardRegion: CGRect {
        CGRect(x: 0, y: 0, width: size.width, height: barFrame.minY)
    }

    /// How much the card's reference box is scaled: to the full width when the height allows.
    var cardScale: CGFloat {
        let byWidth = size.width / Self.cardReferenceSize.width
        let byHeight = cardRegion.height / Self.cardReferenceSize.height
        return max(min(byWidth, byHeight), 0)
    }

    var cardFrame: CGRect {
        let width = Self.cardReferenceSize.width * cardScale
        let height = Self.cardReferenceSize.height * cardScale
        return CGRect(
            x: (size.width - width) / 2,
            y: cardRegion.minY + (cardRegion.height - height) / 2,
            width: width,
            height: height
        )
    }

    /// The preview label's frame inside the card, at the card's scale.
    var labelFrameInCard: CGRect {
        let box = Self.labelFrameInReference
        return CGRect(
            x: box.minX * cardScale,
            y: box.minY * cardScale,
            width: box.width * cardScale,
            height: box.height * cardScale
        )
    }

    /// The full texture art's frame inside the card: scaled with it and shifted up so its
    /// hidden top 20 pt fall outside the card (which clips them).
    var previewArtFrameInCard: CGRect {
        CGRect(
            x: 0,
            y: -Self.previewHiddenTop * cardScale,
            width: Self.previewArtSize.width * cardScale,
            height: Self.previewArtSize.height * cardScale
        )
    }

    /// The back button's tap area in the bar: 44x44, centred on the 33 pt art.
    var backButtonFrameInBar: CGRect {
        let art = Self.backArtFrame
        let side = max(Self.minimumTapSize, art.width)
        return CGRect(x: art.midX - side / 2, y: art.midY - side / 2, width: side, height: side)
    }

    var fieldBackgroundFrameInBar: CGRect {
        CGRect(
            x: Self.fieldBackgroundLeft,
            y: Self.fieldTop,
            width: max(size.width - Self.fieldBackgroundLeft - Self.fieldBackgroundRightInset, Self.fieldCapInset * 2),
            height: Self.fieldHeight
        )
    }

    var textFieldFrameInBar: CGRect {
        CGRect(
            x: Self.textFieldLeft,
            y: Self.fieldTop,
            width: max(size.width - Self.textFieldLeft - Self.textFieldRightInset, 0),
            height: Self.fieldHeight
        )
    }
}
