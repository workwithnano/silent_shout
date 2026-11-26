import UIKit

/// What the shout is drawn on: a bundled texture or the camera photo, either of which is just
/// an image here.
struct ShoutBackground: Equatable {
    /// Identifies the picture for equality, so views can tell when to redraw without comparing
    /// pixels: the asset name for a texture, a hash of the file for the photo
    /// (`PhotoBackgroundStore.id(for:)`).
    let id: String
    let image: UIImage

    /// The full-size art of a bundled texture (SPEC.md 6.4).
    static func texture(_ texture: ShoutTexture) -> ShoutBackground {
        ShoutBackground(id: texture.shoutImageName, image: UIImage(named: texture.shoutImageName) ?? UIImage())
    }

    static func == (lhs: ShoutBackground, rhs: ShoutBackground) -> Bool { lhs.id == rhs.id }
}

/// Everything one shout shows: the message, its font and ink, the sizing mode, and the
/// background.
struct ShoutScene: Equatable {
    var text: String
    var font: ShoutFont
    var sizing: ShoutSizing
    var background: ShoutBackground
}

/// The one place a shout is drawn, on screen and for export and Messages.
///
/// - Background: the original view's 25% grey, then the background image aspect-filling the
///   whole area (PLAN ruling 5).
/// - Fit (SPEC 6.2): the text at `TextFitter.shout`'s size in the original 453x302 label
///   (centred, word wrap, any number of lines, vertically centred, clipped), that label
///   stretched over the 480x320 reference canvas, the canvas scaled uniformly to fit the area
///   and centred, multiplied onto the background at the label's alpha.
/// - Scroll (SPEC 6.3): one line at 180 reference points in the ink colour, alpha 0.75, normal
///   blending, vertically centred, across the full width, at the position `MarqueeMotion`
///   gives for the time asked (0, the start position, for an export: PLAN ruling 8).
///
/// Everything here draws into the current UIKit graphics context, so it runs on the main actor.
@MainActor
enum ShoutRenderer {
    /// What to include. The screen draws the marquee itself (it moves), so in scroll mode it
    /// asks for the background only.
    enum Content: Equatable, Sendable {
        case full
        case backgroundOnly
    }

    /// The original view's background colour, normally hidden by the image.
    static let backdropColor = UIColor(white: 0.25, alpha: 1)

    /// The shout as an image of `size` points at `scale` pixels per point: what the screen
    /// shows at that size. In scroll mode the text is drawn where the marquee is `marqueeTime`
    /// seconds in (0: its start position, which is what an export uses).
    static func image(
        of scene: ShoutScene,
        size: CGSize,
        scale: CGFloat,
        marqueeTime: TimeInterval = 0,
        content: Content = .full
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            draw(scene, in: size, context: context.cgContext, marqueeTime: marqueeTime, content: content)
        }
    }

    /// Draws the shout into `context` (made current for the duration) over `size` points.
    static func draw(
        _ scene: ShoutScene,
        in size: CGSize,
        context: CGContext,
        marqueeTime: TimeInterval = 0,
        content: Content = .full
    ) {
        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }
        drawBackground(scene.background, in: size, context: context)
        guard content == .full else { return }
        let canvas = ShoutCanvas(size: size)
        switch scene.sizing {
        case .scaleToFit:
            drawFitText(scene.text, font: scene.font, canvas: canvas, context: context)
        case .scroll:
            drawMarquee(scene.text, font: scene.font, canvas: canvas, time: marqueeTime, appliesAlpha: true, context: context)
        }
    }

    static func drawBackground(_ background: ShoutBackground, in size: CGSize, context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setFillColor(backdropColor.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        context.clip(to: CGRect(origin: .zero, size: size))
        background.image.draw(in: ShoutCanvas.aspectFillRect(imageSize: background.image.size, in: size))
    }

    // MARK: Fit

    /// The fit-mode font size for `text`, in reference points.
    static func fitFontSize(for text: String, font: ShoutFont) -> CGFloat {
        TextFitter.shout.fontSize(for: text, fontName: font.fontName)
    }

    static func drawFitText(_ text: String, font: ShoutFont, canvas: ShoutCanvas, context: CGContext) {
        guard !text.isEmpty, canvas.scale > 0 else { return }
        let labelSize = ShoutCanvas.fitLabelSize
        let fontSize = fitFontSize(for: text, font: font)
        // A UILabel draws the text, as in the original, so line breaks, vertical centring and
        // clipping are UILabel's own.
        let label = UILabel(frame: CGRect(origin: .zero, size: labelSize))
        label.numberOfLines = 0
        label.textAlignment = .center
        label.lineBreakMode = .byWordWrapping
        label.backgroundColor = .clear
        label.font = font.uiFont(size: fontSize) ?? .systemFont(ofSize: fontSize)
        label.textColor = font.ink.uiColor
        label.text = text

        let frame = canvas.canvasFrame
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: frame.minX, y: frame.minY)
        let factor = canvas.scale * ShoutCanvas.fitLabelStretch
        context.scaleBy(x: factor, y: factor)
        context.clip(to: CGRect(origin: .zero, size: labelSize))
        // The label's bitmap, with the label's alpha, multiplied onto the background.
        context.setAlpha(ShoutCanvas.fitTextAlpha)
        context.setBlendMode(.multiply)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        label.drawText(in: label.bounds)
        context.endTransparencyLayer()
    }

    // MARK: Scroll

    static func marqueeFont(_ font: ShoutFont) -> UIFont {
        font.uiFont(size: ShoutCanvas.marqueeFontSize) ?? .systemFont(ofSize: ShoutCanvas.marqueeFontSize)
    }

    static func marqueeAttributes(_ font: ShoutFont) -> [NSAttributedString.Key: Any] {
        [.font: marqueeFont(font), .foregroundColor: font.ink.uiColor]
    }

    /// The marquee's motion for `text` on `canvas` (the line's width as `sizeToFit` gave it).
    static func marqueeMotion(for text: String, font: ShoutFont, canvas: ShoutCanvas) -> MarqueeMotion {
        let width = text.isEmpty ? 0 : (text as NSString).size(withAttributes: marqueeAttributes(font)).width.rounded(.up)
        return MarqueeMotion(textWidth: width, viewWidth: canvas.marqueeWidth)
    }

    /// Draws the marquee at `time` seconds. `appliesAlpha` composites it at 0.75 as one layer;
    /// the on-screen view passes false and sets its own layer's opacity instead, which is
    /// the same picture without an offscreen pass every frame.
    static func drawMarquee(
        _ text: String,
        font: ShoutFont,
        canvas: ShoutCanvas,
        time: TimeInterval,
        appliesAlpha: Bool,
        context: CGContext
    ) {
        guard !text.isEmpty, canvas.scale > 0 else { return }
        let attributes = marqueeAttributes(font)
        let motion = marqueeMotion(for: text, font: font, canvas: canvas)
        let lineHeight = marqueeFont(font).lineHeight.rounded(.up)

        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: CGRect(origin: .zero, size: canvas.size))
        // Reference points from the left edge, with y 0 on the vertical centre (ruling 14).
        context.translateBy(x: 0, y: canvas.size.height / 2)
        context.scaleBy(x: canvas.scale, y: canvas.scale)
        if appliesAlpha {
            context.setAlpha(ShoutCanvas.marqueeAlpha)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
        }
        for x in motion.copyOrigins(at: time) {
            (text as NSString).draw(at: CGPoint(x: x, y: -lineHeight / 2), withAttributes: attributes)
        }
        if appliesAlpha {
            context.endTransparencyLayer()
        }
    }
}
