import QuartzCore
import UIKit

/// The numbers the on-screen marquee's layers are built from, for one text on one screen
/// (SPEC.md 6.3). Points are screen points; the motion itself is `MarqueeMotion`'s, in
/// reference points, scaled by `ShoutCanvas.scale`.
struct MarqueeLayerPlan: Equatable, Sendable {
    let motion: MarqueeMotion
    /// Screen points per reference point.
    let scale: CGFloat

    init(motion: MarqueeMotion, scale: CGFloat) {
        self.motion = motion
        self.scale = scale
    }

    /// Where the first copy's leading edge sits when the marquee starts (or for good, when the
    /// text fits): `MarqueeMotion.copyOrigins(at: 0)`, in screen points.
    var startX: CGFloat { (motion.copyOrigins(at: 0).first ?? 0) * scale }

    /// From one copy to the next: text width plus the 20 pt gap, in screen points.
    var instanceShift: CGFloat { motion.wrapDistance * scale }

    /// Copies the replicator draws. The strip's position runs from the lead-in (+200) down to
    /// just above -wrapDistance, and every copy that can then start left of the right edge must
    /// exist: 1 + ceil(viewWidth / wrapDistance), which is 2 for any text that scrolls (it is
    /// wider than the screen), as `MarqueeMotion.copyOrigins` gives at most two.
    var instanceCount: Int {
        guard motion.scrolls else { return 1 }
        return 1 + Int((motion.viewWidth / motion.wrapDistance).rounded(.up))
    }

    struct Segment: Equatable, Sendable {
        /// The strip's x, screen points.
        let from: CGFloat
        let to: CGFloat
        let duration: CFTimeInterval
        /// Seconds after the marquee starts.
        let delay: CFTimeInterval
        let repeats: Bool
    }

    /// The lead-in: from 200 pt in to the left edge at 90 pt/s, once. Nil if it does not scroll.
    var leadIn: Segment? {
        guard motion.scrolls else { return nil }
        let duration = CFTimeInterval(MarqueeMotion.leadIn / MarqueeMotion.speed)
        return Segment(from: startX, to: 0, duration: duration, delay: 0, repeats: false)
    }

    /// Then forever: from the left edge to one copy further left, which shows the same picture
    /// as the left edge (the next copy is there), so the jump back is invisible.
    var loop: Segment? {
        guard let leadIn else { return nil }
        let duration = CFTimeInterval(motion.wrapDistance / MarqueeMotion.speed)
        return Segment(from: 0, to: -instanceShift, duration: duration, delay: leadIn.duration, repeats: true)
    }

    /// The strip's x at `time` seconds, as the two segments put it: `-offset(at:)` scaled.
    func stripX(at time: TimeInterval) -> CGFloat {
        motion.scrolls ? -motion.offset(at: time) * scale : startX
    }

    /// The stretches of the line (reference points from its origin) that are on screen at
    /// `time`, widened by `margin` reference points each side, one per copy.
    func visibleTextRanges(at time: TimeInterval, margin: CGFloat) -> [ClosedRange<CGFloat>] {
        let x = scale > 0 ? stripX(at: time) / scale : 0
        return (0..<instanceCount).map { k in
            let origin = x + CGFloat(k) * motion.wrapDistance
            return (-margin - origin)...(motion.viewWidth + margin - origin)
        }
    }
}

/// The scrolling marquee on screen, on Core Animation: the line is rasterized once, a chunk at
/// a time, into alpha-only bitmaps; a replicator repeats them after the 20 pt gap; and two
/// position animations (the lead-in, then a seamless repeat forever) move the strip. Nothing is
/// drawn per frame in the app: the render server moves the layers.
///
/// Layers: this view (alpha 0.75, SPEC 6.3) holds one ink-coloured layer the size of the
/// screen, masked by the replicator, whose instances are the chunk layers. The ink is one
/// colour, so the chunks hold only coverage (one byte a pixel) and the colour comes from the
/// masked layer.
///
/// The time starts when the view first has text and a window; changing the text or font starts
/// it again; a new size rebuilds the layers and keeps the time. Animations are re-added with
/// the same start whenever the view re-enters a window or the app returns to the foreground
/// (Core Animation drops them in the background), so the marquee continues where the clock is.
final class MarqueeView: UIView {
    /// Above this many bytes of bitmaps (a very long message), only chunks near the screen keep
    /// theirs; see `refreshContents`.
    static let eagerBitmapBudget = 48 * 1_000_000
    /// How often the windowed mode looks ahead, and how far (reference points beyond each edge).
    static let refreshInterval: TimeInterval = 0.5
    static func lookAhead(viewWidth: CGFloat) -> CGFloat { viewWidth + MarqueeMotion.speed * 2 }

    static let leadInKey = "marquee.leadIn"
    static let loopKey = "marquee.loop"

    private(set) var text = ""
    private(set) var font: ShoutFont = .pencil
    private(set) var canvas = ShoutCanvas(size: .zero)
    private(set) var displayScale: CGFloat = 0
    /// Media time (`CACurrentMediaTime`) the marquee started at.
    private(set) var startTime: CFTimeInterval?
    private(set) var plan: MarqueeLayerPlan?
    private(set) var line: MarqueeLine?
    /// True when the bitmaps are over budget and only those near the screen are kept.
    private(set) var isWindowed = false

    let inkLayer = CALayer()
    private let maskRoot = CALayer()
    /// The moving strip: one copy of the line as chunk layers, repeated by the replicator.
    let strip = CAReplicatorLayer()
    private(set) var chunkLayers: [ChunkLayer] = []
    private var refreshTimer: Timer?

    struct ChunkLayer {
        let layer: CALayer
        let chunk: MarqueeLine.Chunk
        /// The chunk's ink along the line, reference points.
        let inkSpan: ClosedRange<CGFloat>
        let bytes: Int
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        clipsToBounds = true
        // The whole marquee at 0.75 (SPEC 6.3); the ink itself is opaque.
        alpha = ShoutCanvas.marqueeAlpha
        strip.anchorPoint = .zero
        maskRoot.addSublayer(strip)
        inkLayer.mask = maskRoot
        layer.addSublayer(inkLayer)
        NotificationCenter.default.addObserver(
            self, selector: #selector(willEnterForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func configure(text: String, font: ShoutFont, size: CGSize, displayScale: CGFloat) {
        let textChanged = text != self.text || font != self.font
        let geometryChanged = size != canvas.size || displayScale != self.displayScale
        guard textChanged || geometryChanged else { return }
        self.text = text
        self.font = font
        canvas = ShoutCanvas(size: size)
        self.displayScale = displayScale
        if textChanged {
            startTime = nil
            line = text.isEmpty ? nil : MarqueeLine(text: text, font: ShoutRenderer.marqueeFont(font))
        }
        rebuild()
    }

    /// Seconds since the marquee started, 0 before it has.
    var elapsed: TimeInterval {
        guard let startTime else { return 0 }
        return CACurrentMediaTime() - startTime
    }

    var scrolls: Bool { plan?.motion.scrolls ?? false }

    override func layoutSubviews() {
        super.layoutSubviews()
        withoutActions {
            inkLayer.frame = bounds
            maskRoot.frame = bounds
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateMotion()
    }

    @objc private func willEnterForeground() {
        updateMotion()
    }

    // MARK: Layers

    private func rebuild() {
        withoutActions {
            chunkLayers.forEach { $0.layer.removeFromSuperlayer() }
            chunkLayers = []
            strip.removeAllAnimations()
            plan = nil
            isWindowed = false
            inkLayer.backgroundColor = font.ink.uiColor.cgColor

            guard let line, canvas.scale > 0, displayScale > 0 else { return }
            let motion = ShoutRenderer.marqueeMotion(for: text, font: font, canvas: canvas)
            let plan = MarqueeLayerPlan(motion: motion, scale: canvas.scale)
            self.plan = plan

            // The line's start on screen, kept on whole pixels for the strip; the fractions go
            // into the bitmaps, so at rest (and in the first frame) the glyphs sit exactly where
            // the renderer puts them, with no resampling.
            let baselineY = canvas.size.height / 2 + line.baselineFromCentre * canvas.scale
            let stripY = (baselineY * displayScale).rounded(.down) / displayScale
            let stripX = (plan.startX * displayScale).rounded(.down) / displayScale
            let offset = CGPoint(x: (plan.startX - stripX) * displayScale, y: (baselineY - stripY) * displayScale)
            let pixelsPerPoint = canvas.scale * displayScale
            stripShift = stripX - plan.startX

            strip.position = CGPoint(x: stripX, y: stripY)
            strip.instanceCount = plan.instanceCount
            strip.instanceTransform = CATransform3DMakeTranslation(plan.instanceShift, 0, 0)

            for chunk in line.chunks(pixelsPerPoint: pixelsPerPoint) {
                let rect = line.pixelRect(of: chunk, pixelsPerPoint: pixelsPerPoint, offset: offset)
                guard !rect.isNull else { continue }
                let layer = CALayer()
                layer.contentsScale = displayScale
                layer.frame = CGRect(
                    x: rect.minX / displayScale, y: rect.minY / displayScale,
                    width: rect.width / displayScale, height: rect.height / displayScale
                )
                strip.addSublayer(layer)
                chunkLayers.append(ChunkLayer(
                    layer: layer, chunk: chunk,
                    inkSpan: ((rect.minX - offset.x) / pixelsPerPoint)...((rect.maxX - offset.x) / pixelsPerPoint),
                    bytes: Int(rect.width) * Int(rect.height)
                ))
            }
            let total = chunkLayers.reduce(0) { $0 + $1.bytes }
            isWindowed = plan.motion.scrolls && total > Self.eagerBitmapBudget
            chunkOffset = offset
            refreshContents()
        }
        updateMotion()
    }

    /// The fraction of a pixel the bitmaps carry (see `rebuild`).
    private var chunkOffset: CGPoint = .zero
    /// What the strip's x is moved by so that its bitmaps sit on whole pixels at the start
    /// (minus the x fraction they carry), screen points; added to every animated value.
    private(set) var stripShift: CGFloat = 0

    /// Gives each chunk its bitmap. Normally all of them, once. In windowed mode (a message so
    /// long that every bitmap together would pass `eagerBitmapBudget`), only chunks within
    /// `lookAhead` of either screen edge, for any copy, keep a bitmap; the rest are emptied.
    /// A timer calls this every half second while the marquee runs: at 90 pt/s the strip moves
    /// 45 pt in that time, far less than the look-ahead, so a chunk is drawn well before it
    /// arrives.
    func refreshContents() {
        refreshContents(at: elapsed)
    }

    /// `refreshContents` for the marquee `time` seconds in.
    func refreshContents(at time: TimeInterval) {
        guard let line, let plan else { return }
        let pixelsPerPoint = canvas.scale * displayScale
        let ranges = isWindowed
            ? plan.visibleTextRanges(at: time, margin: Self.lookAhead(viewWidth: plan.motion.viewWidth))
            : nil
        withoutActions {
            for item in chunkLayers {
                let wanted = ranges?.contains { $0.overlaps(item.inkSpan) } ?? true
                if wanted, item.layer.contents == nil {
                    item.layer.contents = line.alphaImage(
                        of: item.chunk, pixelsPerPoint: pixelsPerPoint, offset: chunkOffset
                    )
                } else if !wanted, item.layer.contents != nil {
                    item.layer.contents = nil
                }
            }
        }
    }

    /// Bytes of bitmap currently held by the chunk layers.
    var heldBitmapBytes: Int {
        chunkLayers.reduce(0) { $0 + ($1.layer.contents == nil ? 0 : $1.bytes) }
    }

    // MARK: Motion

    /// Starts the clock and (re)installs the animations while the view is in a window and the
    /// text scrolls; removes them otherwise. Re-adding uses the same start time, so the strip
    /// continues where the clock says rather than starting over.
    private func updateMotion() {
        guard window != nil, let plan, let leadIn = plan.leadIn, let loop = plan.loop else {
            strip.removeAllAnimations()
            stopRefreshTimer()
            return
        }
        if startTime == nil { startTime = CACurrentMediaTime() }
        guard let startTime else { return }
        let begin = strip.convertTime(startTime, from: nil)
        strip.removeAllAnimations()
        strip.add(animation(leadIn, begin: begin), forKey: Self.leadInKey)
        strip.add(animation(loop, begin: begin), forKey: Self.loopKey)
        if isWindowed {
            refreshContents()
            startRefreshTimer()
        } else {
            stopRefreshTimer()
        }
    }

    private func animation(_ segment: MarqueeLayerPlan.Segment, begin: CFTimeInterval) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = segment.from + stripShift
        animation.toValue = segment.to + stripShift
        animation.duration = segment.duration
        animation.beginTime = begin + segment.delay
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.repeatCount = segment.repeats ? .infinity : 0
        animation.isRemovedOnCompletion = false
        // The lead-in holds its end (the left edge) afterwards; the loop, added after it,
        // overrides it from its own begin time on.
        animation.fillMode = segment.repeats ? .removed : .both
        return animation
    }

    private func startRefreshTimer() {
        guard refreshTimer == nil else { return }
        let timer = Timer(timeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshContents() }
        }
        timer.tolerance = Self.refreshInterval / 5
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func withoutActions(_ body: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body()
        CATransaction.commit()
    }
}
