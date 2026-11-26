import QuartzCore
import Testing
import UIKit
@testable import SilentShout

/// The on-screen marquee on Core Animation (SPEC.md 6.3): how the line is cut into chunks, the
/// layers and animations `MarqueeView` installs, and that the result looks like the renderer's
/// marquee (which an export uses).
@Suite("Marquee layers", .serialized)
@MainActor
struct MarqueeLayerTests {
    /// iPhone 17 Pro in landscape at 3x: 874x402 points.
    static let screen = CGSize(width: 874, height: 402)
    static let screenScale: CGFloat = 3
    static var pixelsPerPoint: CGFloat { ShoutCanvas(size: screen).scale * screenScale }

    static let recordingMessage = "Happy birthday Sam! We are over here by the cake"
    static let fiftyCharacters = "Happy birthday Sam! We are over here by the cake!!"
    static var fiveHundredCharacters: String {
        String(repeating: "Welcome home Grandma and Grandpa, we missed you!! ", count: 10)
    }
    static let unbrokenWord = String(repeating: "Wheeeeee", count: 40)

    static let messages: [(String, ShoutFont)] = [
        (recordingMessage, .dryErase),
        ("Can you pick up milk on the way home?", .keyboard),
        ("Gate B12 → over here, ﬁnally", .pencil),
        (unbrokenWord, .dryErase),
        (fiveHundredCharacters, .dryErase),
    ]

    private func line(_ text: String, _ font: ShoutFont) -> MarqueeLine {
        MarqueeLine(text: text, font: ShoutRenderer.marqueeFont(font))
    }

    // MARK: Chunks

    @Test func chunksCoverTheWholeLineWithNoGapsOrOverlaps() {
        for (text, font) in Self.messages {
            let line = line(text, font)
            let chunks = line.chunks(pixelsPerPoint: Self.pixelsPerPoint)
            #expect(!chunks.isEmpty, "\(text)")
            // Every glyph exactly once, in order.
            #expect(chunks.first?.glyphs.lowerBound == 0)
            #expect(chunks.last?.glyphs.upperBound == line.glyphs.count)
            for (a, b) in zip(chunks, chunks.dropFirst()) {
                #expect(a.glyphs.upperBound == b.glyphs.lowerBound)
                #expect(a.span.upperBound == b.span.lowerBound)
                #expect(!a.glyphs.isEmpty)
            }
            // The spans run from the line's origin to its full width.
            #expect(abs((chunks.first?.span.lowerBound ?? 1)) < 1e-6)
            #expect(abs((chunks.last?.span.upperBound ?? 0) - line.width) < 1e-6)
            // And that width is the one NSString measures (which the motion uses).
            let measured = (text as NSString).size(withAttributes: ShoutRenderer.marqueeAttributes(font)).width
            #expect(abs(line.width - measured) < 0.01, "\(text): \(line.width) vs \(measured)")
        }
    }

    @Test func chunksAreWordsWithTheirTrailingSpaces() {
        let line = line("Happy birthday Sam!", .dryErase)
        let chunks = line.chunks(pixelsPerPoint: Self.pixelsPerPoint)
        #expect(chunks.count == 3)
        #expect(chunks.map(\.glyphs.count) == [6, 9, 4])
    }

    @Test func chunkBitmapsStayUnderTheTextureLimit() {
        for scale in [2.0, 3.0] {
            let pixelsPerPoint = ShoutCanvas(size: CGSize(width: 956, height: 440)).scale * scale
            for (text, font) in Self.messages {
                let line = line(text, font)
                for chunk in line.chunks(pixelsPerPoint: pixelsPerPoint) {
                    let rect = line.pixelRect(of: chunk, pixelsPerPoint: pixelsPerPoint)
                    guard !rect.isNull else { continue }
                    #expect(rect.width <= CGFloat(MarqueeLine.maxTexturePixels), "\(text) at \(scale)x: \(rect.width)")
                    #expect(rect.height <= CGFloat(MarqueeLine.maxTexturePixels))
                }
            }
        }
        // The unbroken word had to be cut by glyph range.
        #expect(line(Self.unbrokenWord, .dryErase).chunks(pixelsPerPoint: Self.pixelsPerPoint).count > 3)
    }

    /// The chunks' bitmaps, each placed at its pixel rect, add up to the line exactly as one
    /// `NSString.draw` of the whole line draws it (same glyphs, kerning, baseline, overhang).
    @Test func chunkBitmapsTogetherAreTheWholeLine() throws {
        for (text, font) in Self.messages.prefix(4) {
            let line = line(text, font)
            let k = Self.pixelsPerPoint
            let pad = 200
            let width = Int((line.width * k).rounded(.up)) + 2 * pad
            let height = Int((line.font.lineHeight * k).rounded(.up)) + 2 * pad
            let originX = CGFloat(pad)
            let baseline = CGFloat(pad) + (line.baselineFromTop * k).rounded()

            // A fraction of a pixel, as the view carries in its bitmaps.
            let offset = CGPoint(x: 0.4, y: 0.7)

            // The whole line, drawn the way ShoutRenderer draws it.
            var expected = [UInt8](repeating: 0, count: width * height)
            try expected.withUnsafeMutableBytes { buffer in
                let context = try #require(CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
                ))
                context.translateBy(x: 0, y: CGFloat(height))
                context.scaleBy(x: 1, y: -1)
                UIGraphicsPushContext(context)
                context.scaleBy(x: k, y: k)
                (text as NSString).draw(
                    at: CGPoint(x: (originX + offset.x) / k, y: (baseline + offset.y) / k - line.baselineFromTop),
                    withAttributes: ShoutRenderer.marqueeAttributes(font)
                )
                UIGraphicsPopContext()
            }

            // The chunks, composited source-over at their places.
            var actual = [UInt8](repeating: 0, count: width * height)
            try actual.withUnsafeMutableBytes { buffer in
                let context = try #require(CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
                ))
                for chunk in line.chunks(pixelsPerPoint: k) {
                    let rect = line.pixelRect(of: chunk, pixelsPerPoint: k, offset: offset)
                    guard let image = line.alphaImage(of: chunk, pixelsPerPoint: k, offset: offset) else { continue }
                    #expect(image.width == Int(rect.width) && image.height == Int(rect.height))
                    #expect(image.bitsPerPixel == 8, "single channel: \(image.bitsPerPixel) bits a pixel")
                    // An alpha-only context's image comes back as an 8-bit image mask (coverage only).
                    #expect(image.isMask || image.alphaInfo == .alphaOnly, "single channel: mask \(image.isMask), alpha \(image.alphaInfo.rawValue)")
                    let top = baseline + rect.minY
                    #expect(top >= 0 && originX + rect.minX >= 0, "\(text): chunk inside the test bitmap")
                    // y up here: the chunk's top row lands `top` rows below the bitmap's top.
                    context.draw(image, in: CGRect(
                        x: originX + rect.minX, y: CGFloat(height) - top - rect.height,
                        width: rect.width, height: rect.height
                    ))
                }
            }

            var ink = 0, off = 0, worst = 0
            expected.withUnsafeBufferPointer { e in
                actual.withUnsafeBufferPointer { a in
                    for i in 0..<e.count {
                        if e[i] > 0 { ink += 1 }
                        let d = abs(Int(e[i]) - Int(a[i]))
                        if d > 24 { off += 1 }
                        if d > worst { worst = d }
                    }
                }
            }
            print("chunks vs whole line, \(text): \(off) of \(ink) ink pixels differ by more than 24, worst \(worst)")
            #expect(ink > 10_000, "\(text): the reference has ink")
            // Nothing missing at all: no clipped tail or loop would pass this.
            #expect(off == 0, "\(text): \(off) of \(ink) ink pixels differ by more than 24 (worst \(worst))")
        }
    }

    // MARK: Plan

    @Test func animationsMatchTheMotion() throws {
        let motion = MarqueeMotion(textWidth: 1800, viewWidth: 695)
        let plan = MarqueeLayerPlan(motion: motion, scale: 1.25)
        let leadIn = try #require(plan.leadIn)
        let loop = try #require(plan.loop)
        #expect(leadIn.from == 250 && leadIn.to == 0)
        #expect(abs(leadIn.duration - 200.0 / 90.0) < 1e-9)
        #expect(!leadIn.repeats && leadIn.delay == 0)
        #expect(loop.from == 0 && loop.to == -1820 * 1.25)
        #expect(abs(loop.duration - 1820.0 / 90.0) < 1e-9)
        #expect(loop.repeats)
        #expect(abs(loop.delay - 200.0 / 90.0) < 1e-9)
        // The strip is where MarqueeMotion puts the first copy, at any time.
        for step in 0..<500 {
            let time = Double(step) * 0.173
            let first = motion.copyOrigins(at: time)[0]
            #expect(abs(plan.stripX(at: time) - first * 1.25) < 1e-6)
        }
    }

    /// Every copy `MarqueeMotion` says can be visible is one of the replicator's instances, for
    /// text barely wider than the screen and for very long text.
    @Test func replicatorInstancesCoverTheScreenAtEveryPhase() {
        for textWidth in [696.0, 900, 1500, 40_000] {
            let motion = MarqueeMotion(textWidth: textWidth, viewWidth: 695)
            let plan = MarqueeLayerPlan(motion: motion, scale: 1)
            #expect(plan.instanceCount == 2)
            let period = motion.wrapDistance / MarqueeMotion.speed
            for step in 0...2000 {
                let time = Double(step) / 2000 * (period * 2 + 3)
                let x = plan.stripX(at: time)
                let instances = (0..<plan.instanceCount).map { x + Double($0) * plan.instanceShift }
                let onScreen = instances.filter { $0 < motion.viewWidth }
                #expect(onScreen.count == motion.copyOrigins(at: time).count, "\(textWidth) at \(time)")
                for (a, b) in zip(onScreen, motion.copyOrigins(at: time)) {
                    #expect(abs(a - b) < 1e-6)
                }
                // Left edge covered: the first instance starts at or before it (or the lead-in's
                // empty start), and the right edge is reached by the last instance.
                let last = instances[instances.count - 1]
                #expect(last + textWidth >= motion.viewWidth || last >= motion.viewWidth)
            }
        }
    }

    @Test func textThatFitsDoesNotMove() {
        let plan = MarqueeLayerPlan(motion: MarqueeMotion(textWidth: 300, viewWidth: 480), scale: 2)
        #expect(plan.leadIn == nil && plan.loop == nil)
        #expect(plan.instanceCount == 1)
        #expect(plan.startX == 180)
    }

    // MARK: The view

    @MainActor
    private final class Host {
        let window: UIWindow
        let backdrop: UIView
        let marquee = MarqueeView()

        init(size: CGSize = MarqueeLayerTests.screen) throws {
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: size)
            let controller = UIViewController()
            backdrop = controller.view
            backdrop.backgroundColor = .white
            marquee.frame = CGRect(origin: .zero, size: size)
            backdrop.addSubview(marquee)
            window.rootViewController = controller
            window.isHidden = false
            backdrop.layoutIfNeeded()
        }

        func close() { window.isHidden = true }
    }

    @Test func installsTheTwoAnimationsWhenTheTextScrolls() throws {
        let host = try Host()
        defer { host.close() }
        host.marquee.configure(text: Self.recordingMessage, font: .dryErase, size: Self.screen, displayScale: Self.screenScale)
        let marquee = host.marquee
        let plan = try #require(marquee.plan)
        #expect(plan.motion.scrolls)
        #expect(marquee.strip.instanceCount == 2)
        #expect(abs(marquee.strip.instanceTransform.m41 - plan.instanceShift) < 1e-9)
        let leadIn = try #require(marquee.strip.animation(forKey: MarqueeView.leadInKey) as? CABasicAnimation)
        let loop = try #require(marquee.strip.animation(forKey: MarqueeView.loopKey) as? CABasicAnimation)
        #expect(leadIn.keyPath == "position.x" && loop.keyPath == "position.x")
        // Each value is moved by the same fraction of a pixel the bitmaps carry (under one pixel).
        let shift = marquee.stripShift
        #expect(abs(shift) < 1 / Self.screenScale)
        #expect(leadIn.fromValue as? CGFloat == plan.startX + shift && leadIn.toValue as? CGFloat == shift)
        #expect(loop.fromValue as? CGFloat == shift && loop.toValue as? CGFloat == -plan.instanceShift + shift)
        #expect(loop.repeatCount == .infinity && leadIn.repeatCount == 0)
        #expect(abs(loop.duration - Double(plan.motion.wrapDistance / 90)) < 1e-9)
        #expect(abs(loop.beginTime - leadIn.beginTime - 200.0 / 90.0) < 1e-9)
        #expect(!leadIn.isRemovedOnCompletion && !loop.isRemovedOnCompletion)
        #expect(loop.timingFunction == CAMediaTimingFunction(name: .linear))
        #expect(!marquee.isWindowed)
        #expect(marquee.chunkLayers.allSatisfy { $0.layer.contents != nil })

        // Out of the window: no animations; back in: the same start, not a new one.
        let start = try #require(marquee.startTime)
        marquee.removeFromSuperview()
        #expect(marquee.strip.animationKeys() == nil)
        host.backdrop.addSubview(marquee)
        #expect(marquee.startTime == start)
        let again = try #require(marquee.strip.animation(forKey: MarqueeView.leadInKey))
        #expect(abs(again.beginTime - leadIn.beginTime) < 1e-9)

        // The app returning from the background puts them back the same way.
        marquee.strip.removeAllAnimations()
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        #expect(marquee.strip.animation(forKey: MarqueeView.loopKey) != nil)
        #expect(marquee.startTime == start)
    }

    @Test func nothingMovesWhenTheTextFits() throws {
        let host = try Host()
        defer { host.close() }
        host.marquee.configure(text: "Hi", font: .dryErase, size: Self.screen, displayScale: Self.screenScale)
        #expect(host.marquee.strip.animationKeys() == nil)
        #expect(host.marquee.strip.instanceCount == 1)
        #expect(!host.marquee.scrolls)
        let plan = try #require(host.marquee.plan)
        #expect(abs(host.marquee.strip.position.x - plan.startX) < 1 / Self.screenScale)
        #expect(plan.startX > 0, "centred")

        host.marquee.configure(text: "", font: .dryErase, size: Self.screen, displayScale: Self.screenScale)
        #expect(host.marquee.chunkLayers.isEmpty)
        #expect(host.marquee.strip.animationKeys() == nil)
    }

    @Test func aNewSizeRebuildsAndKeepsTheClock() throws {
        let host = try Host()
        defer { host.close() }
        let marquee = host.marquee
        marquee.configure(text: Self.recordingMessage, font: .dryErase, size: Self.screen, displayScale: Self.screenScale)
        let start = try #require(marquee.startTime)
        let layers = marquee.chunkLayers.map(\.layer)
        // The same size again (a turn between the two landscapes) changes nothing.
        marquee.configure(text: Self.recordingMessage, font: .dryErase, size: Self.screen, displayScale: Self.screenScale)
        #expect(marquee.chunkLayers.map(\.layer) == layers)
        marquee.configure(text: Self.recordingMessage, font: .dryErase, size: CGSize(width: 956, height: 440), displayScale: Self.screenScale)
        #expect(marquee.chunkLayers.map(\.layer) != layers)
        #expect(marquee.startTime == start)
        // New text starts again.
        marquee.configure(text: Self.recordingMessage + "!", font: .dryErase, size: CGSize(width: 956, height: 440), displayScale: Self.screenScale)
        #expect(marquee.startTime != start)
    }

    /// Memory at 3x on an iPhone 17 Pro (874x402 pt): one byte a pixel for each chunk.
    @Test func memoryForLongMessages() throws {
        let fifty = line(Self.fiftyCharacters, .dryErase).bitmapBytes(pixelsPerPoint: Self.pixelsPerPoint)
        let fiveHundred = line(Self.fiveHundredCharacters, .dryErase).bitmapBytes(pixelsPerPoint: Self.pixelsPerPoint)
        #expect(Self.fiftyCharacters.count == 50 && Self.fiveHundredCharacters.count == 500)
        print("marquee bitmaps at 3x: 50 characters \(fifty) bytes, 500 characters \(fiveHundred) bytes")
        #expect(fifty < MarqueeView.eagerBitmapBudget)

        let host = try Host()
        defer { host.close() }
        let marquee = host.marquee
        marquee.configure(text: Self.fiveHundredCharacters, font: .dryErase, size: Self.screen, displayScale: Self.screenScale)
        #expect(marquee.isWindowed == (fiveHundred > MarqueeView.eagerBitmapBudget))
        print("500 characters, held at the start: \(marquee.heldBitmapBytes) bytes of \(fiveHundred)")
        if marquee.isWindowed {
            #expect(marquee.heldBitmapBytes < fiveHundred / 4)
            // Every chunk on screen (either copy) has its bitmap now and at later times.
            let plan = try #require(marquee.plan)
            for time in [0.0, 5, 30, 61.5, 200] {
                let visible = plan.visibleTextRanges(at: time, margin: 0)
                let ranges = plan.visibleTextRanges(at: time, margin: MarqueeView.lookAhead(viewWidth: plan.motion.viewWidth))
                for item in marquee.chunkLayers where visible.contains(where: { $0.overlaps(item.inkSpan) }) {
                    #expect(ranges.contains { $0.overlaps(item.inkSpan) })
                }
            }
        }
    }

    // MARK: Against the renderer

    /// The layer tree at time 0, as the render server draws it (`drawHierarchy`, which includes
    /// the mask; `CALayer.render(in:)` ignores masks), against `ShoutRenderer.drawMarquee` at
    /// time 0, which is what an export draws. Both over white.
    @Test func firstFrameMatchesTheRenderer() throws {
        for (text, font) in [(Self.recordingMessage, ShoutFont.dryErase), ("Hi there", .pencil), ("Can you pick up milk on the way home?", .keyboard)] {
            let result = try compareWithRenderer(text, font, at: 0)
            #expect(result.inked > 10_000, "\(text): the renderer drew ink")
            #expect(result.off <= result.inked / 200, "\(text): \(result.off) of \(result.inked) ink pixels differ by more than 40")
            #expect(result.mean < 1, "\(text): mean difference \(result.mean)")
        }
    }

    /// Later on, through the lead-in, across the 20 pt gap and past the first repeat, and for a
    /// message long enough that only chunks near the screen hold bitmaps: the same picture as
    /// the renderer's at that time. The strip then sits at fractions of a pixel, which the render
    /// server resamples, so edges may differ by up to a pixel.
    @Test func laterFramesMatchTheRenderer() throws {
        let width = ShoutRenderer.marqueeMotion(for: Self.recordingMessage, font: .dryErase, canvas: ShoutCanvas(size: Self.screen)).textWidth
        // Seconds at which the gap is mid-screen, and just after the first wrap.
        let gapMidScreen = Double((200 + width + 10 - 350) / 90)
        let afterWrap = Double((200 + width + 20) / 90) + 0.4
        for (text, time) in [(Self.recordingMessage, 1.3), (Self.recordingMessage, gapMidScreen), (Self.recordingMessage, afterWrap), (Self.fiveHundredCharacters, 211.7)] {
            let result = try compareWithRenderer(text, .dryErase, at: time)
            #expect(result.inked > 10_000, "\(time) s: the renderer drew ink")
            // Resampling also softens the finest tips, a few hundred pixels scattered along the
            // whole line (0.07% of the ink, measured); a misplaced chunk or a wrong gap would be
            // thousands in one place.
            #expect(result.misplaced <= result.inked / 500, "\(time) s: \(result.misplaced) of \(result.inked) ink pixels differ by more than 40 from everything within a pixel")
            #expect(result.mean < 2, "\(time) s: mean difference \(result.mean)")
        }
    }

    private struct Comparison {
        let off: Int
        let misplaced: Int
        let inked: Int
        let mean: Double
    }

    private func compareWithRenderer(_ text: String, _ font: ShoutFont, at time: TimeInterval) throws -> Comparison {
        let host = try Host()
        defer { host.close() }
        let marquee = host.marquee
        marquee.configure(text: text, font: font, size: Self.screen, displayScale: Self.screenScale)
        // Hold the strip `time` seconds in, with the bitmaps that time needs.
        // (The strip's own clock, read before it is stopped.)
        if let start = marquee.startTime {
            let begin = marquee.strip.convertTime(start, from: nil)
            marquee.strip.speed = 0
            marquee.strip.timeOffset = begin + time
        }
        marquee.refreshContents(at: time)
        CATransaction.flush()
        if let plan = marquee.plan, let presented = marquee.strip.presentation() {
            #expect(abs(presented.position.x - (plan.stripX(at: time) + marquee.stripShift)) < 0.01, "the strip is where the motion says")
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = Self.screenScale
        format.opaque = true
        let onScreen = UIGraphicsImageRenderer(size: Self.screen, format: format).image { _ in
            _ = host.backdrop.drawHierarchy(in: CGRect(origin: .zero, size: Self.screen), afterScreenUpdates: true)
        }
        let rendered = UIGraphicsImageRenderer(size: Self.screen, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: Self.screen))
            ShoutRenderer.drawMarquee(text, font: font, canvas: ShoutCanvas(size: Self.screen), time: time, appliesAlpha: true, context: context.cgContext)
        }
        let a = try rgbBytes(onScreen), b = try rgbBytes(rendered)
        #expect(a.count == b.count)
        let width = Int(Self.screen.width * Self.screenScale), height = Int(Self.screen.height * Self.screenScale)
        var off = 0, misplaced = 0, inked = 0, total = 0
        a.withUnsafeBufferPointer { a in
            b.withUnsafeBufferPointer { b in
                func difference(_ i: Int, _ j: Int) -> Int {
                    max(abs(Int(a[i]) - Int(b[j])), abs(Int(a[i + 1]) - Int(b[j + 1])), abs(Int(a[i + 2]) - Int(b[j + 2])))
                }
                for i in stride(from: 0, to: min(a.count, b.count), by: 4) {
                    let d = difference(i, i)
                    if b[i + 1] < 250 { inked += 1 }
                    total += d
                    guard d > 40 else { continue }
                    off += 1
                    // Misplaced: nothing within a pixel either way matches. A strip at a fraction
                    // of a pixel is resampled and moves edges by less than that; a seam, a wrong
                    // gap or a missing chunk does not.
                    let x = (i / 4) % width, y = (i / 4) / width
                    var near = false
                    for dy in -1...1 where y + dy >= 0 && y + dy < height {
                        for dx in -1...1 where x + dx >= 0 && x + dx < width {
                            if difference(i, ((y + dy) * width + x + dx) * 4) <= 40 { near = true }
                        }
                    }
                    if !near { misplaced += 1 }
                }
            }
        }
        let mean = Double(total) / Double(max(a.count / 4, 1))
        print("on screen vs renderer, \(text.prefix(30)) at \(time) s: \(off) pixels off by > 40 (\(misplaced) not within a pixel), mean difference \(mean), ink pixels \(inked), bitmaps held \(marquee.heldBitmapBytes)")
        return Comparison(off: off, misplaced: misplaced, inked: inked, mean: mean)
    }

    private func rgbBytes(_ image: UIImage) throws -> [UInt8] {
        let cgImage = try #require(image.cgImage)
        let width = cgImage.width, height = cgImage.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return bytes
    }
}
