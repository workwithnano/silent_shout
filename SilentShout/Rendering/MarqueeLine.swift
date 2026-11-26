import CoreGraphics
import CoreText
import UIKit

/// The marquee's one line of text, laid out once by Core Text and cut into chunks that are each
/// rasterized into their own small single-channel bitmap (SPEC.md 6.3).
///
/// The whole line is one `CTLine`, so spacing, kerning and ligatures are exactly what one
/// `NSString.draw` of the line gives; chunks only group that line's glyphs and never lay
/// anything out themselves. A chunk is a word with its trailing spaces, cut further by glyph
/// range if its bitmap would be wider than `maxTexturePixels`.
///
/// Coordinates are reference points (`ShoutCanvas`) with the line's origin at x 0 and its
/// baseline at y 0, y growing downward.
struct MarqueeLine {
    /// The widest bitmap a chunk gets, in pixels. Every iPhone that runs iOS 26 has a GPU limit
    /// of 16384 px per texture side; a quarter of that also keeps each bitmap small enough that
    /// far-away chunks can drop theirs cheaply.
    static let maxTexturePixels = 4096
    /// Pixels of clear border around each chunk's ink, so antialiasing at the glyph outline's
    /// edge is never cut off.
    static let inkPaddingPixels: CGFloat = 2

    struct Glyph {
        let run: Int
        let indexInRun: Int
        let glyph: CGGlyph
        /// The glyph's origin on the baseline, line coordinates (y down).
        let position: CGPoint
        let advance: CGFloat
        /// The glyph outline's bounds (its image, not its advance box), line coordinates, y down.
        /// Null for glyphs without ink (spaces).
        let ink: CGRect
        let isWhitespace: Bool
    }

    struct Chunk: Equatable {
        /// Indexes into `glyphs`, contiguous.
        let glyphs: Range<Int>
        /// The stretch of the line's advance this chunk's glyphs take: from the first glyph's
        /// origin to the next chunk's first origin (the line's width for the last chunk).
        let span: ClosedRange<CGFloat>
        /// The union of the chunk's glyph outlines (line coordinates), null if it has no ink.
        let ink: CGRect
    }

    let text: String
    let font: UIFont
    let line: CTLine
    let runs: [CTRun]
    let glyphs: [Glyph]
    /// Core Text's typographic width of the line, in reference points.
    let width: CGFloat

    init(text: String, font: UIFont) {
        self.text = text
        self.font = font
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        line = CTLineCreateWithAttributedString(attributed)
        runs = (CTLineGetGlyphRuns(line) as? [CTRun]) ?? []
        width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))

        let characters = Array(text.utf16)
        var glyphs: [Glyph] = []
        for (runIndex, run) in runs.enumerated() {
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }
            let runFont = Self.font(of: run, fallback: font)
            var ids = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            var advances = [CGSize](repeating: .zero, count: count)
            var indices = [CFIndex](repeating: 0, count: count)
            var bounds = [CGRect](repeating: .zero, count: count)
            let all = CFRange(location: 0, length: 0)
            CTRunGetGlyphs(run, all, &ids)
            CTRunGetPositions(run, all, &positions)
            CTRunGetAdvances(run, all, &advances)
            CTRunGetStringIndices(run, all, &indices)
            CTFontGetBoundingRectsForGlyphs(runFont, .default, ids, &bounds, count)
            for i in 0..<count {
                let p = positions[i]
                // The font's stored bounds can be a little short of the outline (Kristi's are,
                // by about a pixel at 3x on some strokes); the outline's own bounds are exact.
                var b = bounds[i]
                if let path = CTFontCreatePathForGlyph(runFont, ids[i], nil) {
                    b = b.isEmpty ? path.boundingBoxOfPath : b.union(path.boundingBoxOfPath)
                }
                // Core Text is y up; flip into the line's y-down coordinates.
                let ink = b.isEmpty ? CGRect.null : CGRect(x: p.x + b.minX, y: -p.y - b.maxY, width: b.width, height: b.height)
                let index = indices[i]
                let isWhitespace = index >= 0 && index < characters.count
                    && Character(Unicode.Scalar(characters[index]) ?? "x").isWhitespace
                glyphs.append(Glyph(
                    run: runIndex, indexInRun: i, glyph: ids[i],
                    position: CGPoint(x: p.x, y: -p.y), advance: advances[i].width,
                    ink: ink, isWhitespace: isWhitespace
                ))
            }
        }
        self.glyphs = glyphs
    }

    private static func font(of run: CTRun, fallback: UIFont) -> CTFont {
        let attributes = CTRunGetAttributes(run) as NSDictionary
        if let value = attributes[kCTFontAttributeName] {
            return value as! CTFont // swiftlint:disable:this force_cast (always a CTFont)
        }
        return fallback as CTFont
    }

    /// The baseline's distance below the top of the line box that `NSString.draw(at:)` uses
    /// (the renderer places that box's top at `-lineHeight / 2` from the vertical centre).
    var baselineFromTop: CGFloat { font.ascender }

    /// The line box's height as the renderer rounds it.
    var lineHeight: CGFloat { font.lineHeight.rounded(.up) }

    /// The baseline's y relative to the screen's vertical centre, reference points, y down.
    var baselineFromCentre: CGFloat { -lineHeight / 2 + baselineFromTop }

    // MARK: Chunks

    /// The line cut into chunks for `pixelsPerPoint` pixels per reference point.
    func chunks(pixelsPerPoint: CGFloat) -> [Chunk] {
        guard !glyphs.isEmpty else { return [] }
        // Words: each ends after its trailing whitespace.
        var words: [Range<Int>] = []
        var start = 0
        for i in glyphs.indices {
            let endsWord = glyphs[i].isWhitespace && (i + 1 == glyphs.count || !glyphs[i + 1].isWhitespace)
            if endsWord || i + 1 == glyphs.count {
                words.append(start..<(i + 1))
                start = i + 1
            }
        }
        // Then by glyph range wherever a word's bitmap would be too wide.
        let limit = CGFloat(Self.maxTexturePixels)
        var ranges: [Range<Int>] = []
        for word in words {
            var piece = word.lowerBound
            var ink = CGRect.null
            for i in word {
                let grown = ink.union(glyphs[i].ink)
                if i > piece, !grown.isNull, pixelWidth(of: grown, pixelsPerPoint: pixelsPerPoint) > limit {
                    ranges.append(piece..<i)
                    piece = i
                    ink = glyphs[i].ink
                } else {
                    ink = grown
                }
            }
            ranges.append(piece..<word.upperBound)
        }
        return ranges.enumerated().map { index, range in
            let lower = glyphs[range.lowerBound].position.x
            let upper = index + 1 < ranges.count ? glyphs[ranges[index + 1].lowerBound].position.x : width
            let ink = range.reduce(CGRect.null) { $0.union(glyphs[$1].ink) }
            return Chunk(glyphs: range, span: lower...max(lower, upper), ink: ink)
        }
    }

    /// The bitmap a chunk's ink needs: its outline bounds in pixels, padded, rounded out to
    /// whole pixels, in line pixel coordinates (x from the origin, y down from the baseline),
    /// with the line moved by `offset` pixels (the fraction of a pixel the line's position has
    /// on screen, so the bitmaps can sit on whole pixels and still put the glyphs exactly).
    func pixelRect(of chunk: Chunk, pixelsPerPoint: CGFloat, offset: CGPoint = .zero) -> CGRect {
        guard !chunk.ink.isNull else { return .null }
        let scaled = CGRect(
            x: chunk.ink.minX * pixelsPerPoint + offset.x,
            y: chunk.ink.minY * pixelsPerPoint + offset.y,
            width: chunk.ink.width * pixelsPerPoint,
            height: chunk.ink.height * pixelsPerPoint
        )
        let padded = scaled.insetBy(dx: -Self.inkPaddingPixels, dy: -Self.inkPaddingPixels)
        let minX = padded.minX.rounded(.down), minY = padded.minY.rounded(.down)
        return CGRect(x: minX, y: minY, width: padded.maxX.rounded(.up) - minX, height: padded.maxY.rounded(.up) - minY)
    }

    private func pixelWidth(of ink: CGRect, pixelsPerPoint: CGFloat) -> CGFloat {
        ink.width * pixelsPerPoint + 2 * Self.inkPaddingPixels + 2
    }

    /// The chunk's ink as an alpha-only image (one byte a pixel) covering `pixelRect(of:...)`.
    /// The glyphs are drawn at their places in the whole line, so chunks laid side by side give
    /// the line exactly.
    func alphaImage(of chunk: Chunk, pixelsPerPoint: CGFloat, offset: CGPoint = .zero) -> CGImage? {
        let rect = pixelRect(of: chunk, pixelsPerPoint: pixelsPerPoint, offset: offset)
        guard !rect.isNull, rect.width > 0, rect.height > 0 else { return nil }
        let width = Int(rect.width), height = Int(rect.height)
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ) else { return nil }
        // Line pixel coordinates (y down from the baseline) to this bitmap (y up from its
        // bottom-left corner), then reference points to pixels, y up as Core Text draws.
        context.translateBy(x: -rect.minX + offset.x, y: rect.maxY - offset.y)
        context.scaleBy(x: pixelsPerPoint, y: pixelsPerPoint)
        draw(chunk, in: context)
        return context.makeImage()
    }

    /// Draws a chunk's glyphs into `context`, whose coordinates are reference points with the
    /// line's origin at (0, 0) and y up (Core Text's own orientation).
    func draw(_ chunk: Chunk, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.textMatrix = .identity
        context.setFillColor(gray: 0, alpha: 1)
        var i = chunk.glyphs.lowerBound
        while i < chunk.glyphs.upperBound {
            let run = glyphs[i].run
            var ids: [CGGlyph] = []
            var points: [CGPoint] = []
            while i < chunk.glyphs.upperBound, glyphs[i].run == run {
                ids.append(glyphs[i].glyph)
                // Back to Core Text's y up.
                points.append(CGPoint(x: glyphs[i].position.x, y: -glyphs[i].position.y))
                i += 1
            }
            CTFontDrawGlyphs(Self.font(of: runs[run], fallback: font), ids, points, ids.count, context)
        }
    }

    /// Bytes the chunks' bitmaps take at `pixelsPerPoint` (one byte a pixel).
    func bitmapBytes(pixelsPerPoint: CGFloat) -> Int {
        chunks(pixelsPerPoint: pixelsPerPoint).reduce(0) { total, chunk in
            let rect = pixelRect(of: chunk, pixelsPerPoint: pixelsPerPoint)
            return rect.isNull ? total : total + Int(rect.width) * Int(rect.height)
        }
    }
}
