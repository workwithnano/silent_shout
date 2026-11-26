import SwiftUI
import UIKit

/// The Shout screen, SPEC.md sections 2.3, 6.2, 6.3 and 7: the message on the chosen
/// background, fitted to the screen or scrolling as a marquee, always in landscape, with a
/// toolbar that a tap shows and hides.
///
/// Presented by `ShoutPresenter` in a `ShoutHostingController` (landscape, status bar hidden,
/// home indicator auto-hidden, screen kept awake) while `AppNavigation.isShouting` is true.
/// Back, double-back and turning the phone upright all go through `AppNavigation.endShout`.
struct ShoutView: View {
    @Environment(ShoutSettings.self) private var settings
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.displayScale) private var displayScale

    @State private var isChromeVisible = false
    /// The size the shout keeps while it rotates back to portrait and dissolves away, so it
    /// does not re-lay itself out in portrait on the way out.
    @State private var leavingSize: CGSize?
    @State private var imageCache = ShoutImageCache()
    /// The full-screen size, for the accessibility value (whether the marquee moves) and the
    /// exported picture.
    @State private var screenSize: CGSize = .zero

    // Export (SPEC.md section 9).
    @State private var showsExportSheet = false
    @State private var isSaving = false
    @State private var saveProblem: PhotoSaveResult?
    @State private var showsSavedNote = false
    @State private var isComposing = false
    @State private var composer = MessageComposer()
    private let exportActions = ExportAction.available(messages: DeviceMessageAvailability())

    private var scene: ShoutScene {
        ShoutScene(
            text: settings.text ?? "",
            font: settings.font,
            sizing: settings.sizing,
            background: settings.background
        )
    }

    var body: some View {
        let scene = scene
        ZStack(alignment: .top) {
            GeometryReader { proxy in
                let size = leavingSize ?? proxy.size
                ShoutCanvasView(scene: scene, size: size, displayScale: displayScale, cache: imageCache)
                    .frame(width: size.width, height: size.height)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .accessibilityHidden(true)
                    .onChange(of: navigation.isShouting) { _, shouting in
                        if !shouting { leavingSize = proxy.size }
                    }
            }
            .ignoresSafeArea()
            .onGeometryChange(for: CGSize.self, of: \.size) { size in
                if leavingSize == nil { screenSize = size }
            }

            // The message for VoiceOver as one element, over the whole screen but clear of the
            // toolbar while it shows, so touching the bar finds its buttons. (Its accessibility
            // modifiers come after the frame, so the element has exactly that frame.)
            GeometryReader { proxy in
                let top = isChromeVisible ? ShoutToolbar.height : 0
                Color.clear
                    .frame(width: proxy.size.width, height: max(proxy.size.height - top, 0))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(scene.text.isEmpty ? "No message" : scene.text)
                    .accessibilityValue(isScrolling(scene) ? "Scrolling" : "")
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityHint(isChromeVisible ? "Double-tap to hide the toolbar." : "Double-tap to show the toolbar.")
                    .accessibilityAction(.default, toggleChrome)
                    .accessibilityRemoveTraits(.isButton)
                    .accessibilityIdentifier(ShoutAccessibilityID.text)
                    .offset(y: top)
            }
            // A tap anywhere on the screen, edge to edge, toggles the toolbar. The toolbar's
            // buttons take their own taps; its bar art takes none, so a tap on the bar between
            // the buttons toggles it too, as UIToolbar passed such touches on in the original.
            .contentShape(Rectangle())
            .onTapGesture(perform: toggleChrome)
            .ignoresSafeArea()

            // Inserted and removed with a 0.4 s fade (the original animated alpha 0 to 1),
            // so while hidden it takes no touches and VoiceOver does not find it.
            if isChromeVisible {
                ShoutToolbar(
                    onDoubleBack: { navigation.endShout(returningToOptions: true) },
                    onBack: { navigation.endShout() },
                    onExport: showExportSheet
                )
                .transition(.opacity)
                .accessibilitySortPriority(1)
            }

            if showsSavedNote {
                SavedNote()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 24)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            #if DEBUG
            if UITestHooks.showsShoutState {
                ShoutStateProbe(orientation: navigation.deviceOrientation, isShouting: navigation.isShouting)
            }
            #endif
        }
        .background(Color(uiColor: ShoutRenderer.backdropColor).ignoresSafeArea())
        .alert(
            saveProblem == .denied ? "Can't Save to Photos" : "Couldn't Save",
            isPresented: Binding(get: { saveProblem != nil }, set: { if !$0 { saveProblem = nil } }),
            presenting: saveProblem
        ) { problem in
            if problem == .denied {
                Button("Settings") { openSettings() }
                Button("OK", role: .cancel) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: { problem in
            if problem == .denied {
                Text("Allow Silent Shout to add photos in Settings.")
            } else {
                Text("The shout could not be saved to your photo library.")
            }
        }
        .onChange(of: isCovered, initial: true) { _, covered in
            navigation.setShoutCovered(covered)
        }
    }

    /// Something is presented over the shout: taps do not reach the toolbar toggle and turning
    /// upright does not leave until it has gone (SPEC.md section 1).
    private var isCovered: Bool {
        showsExportSheet || isSaving || saveProblem != nil || isComposing
    }

    /// A tap anywhere but a button shows or hides the toolbar over 0.4 s (SPEC.md 7).
    private func toggleChrome() {
        guard !isCovered else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            isChromeVisible.toggle()
        }
    }

    // MARK: Export

    /// The original's UIActionSheet ("Export Shout": the actions, then Cancel), presented by the
    /// shout's own landscape view controller (`ExportSheet`).
    private func showExportSheet() {
        guard !isCovered else { return }
        showsExportSheet = true
        let presented = ExportSheet.present(actions: exportActions) { action in
            // Mark the next cover before lifting this one, so the shout is never uncovered in
            // between (which could let a pending turn-upright leave under the composer).
            if let action { perform(action) }
            showsExportSheet = false
        }
        if !presented { showsExportSheet = false }
    }

    /// The picture both actions send: the shout as it is on screen, at the screen's pixel size
    /// (PLAN ruling 8).
    private func exportData() -> Data? {
        ShoutExport.pngData(of: scene, size: screenSize, scale: displayScale)
    }

    private func perform(_ action: ExportAction) {
        switch action {
        case .saveToCameraRoll: saveToCameraRoll()
        case .sendInMessages: sendInMessages()
        }
    }

    /// The original saved with no feedback; the rewrite confirms briefly, or explains a refusal
    /// with a way to Settings (QUESTIONS.md).
    private func saveToCameraRoll() {
        guard let data = exportData() else {
            saveProblem = .failed
            return
        }
        isSaving = true
        let saver = ShoutExport.photoSaver
        Task { @MainActor in
            let result = await saver.save(data)
            isSaving = false
            switch result {
            case .saved: showSavedNote()
            case .denied, .failed: saveProblem = result
            }
        }
    }

    private func showSavedNote() {
        UIAccessibility.post(notification: .announcement, argument: SavedNote.text)
        withAnimation(.easeInOut(duration: 0.25)) { showsSavedNote = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.easeInOut(duration: 0.4)) { showsSavedNote = false }
        }
    }

    private func sendInMessages() {
        guard let data = exportData() else { return }
        isComposing = true
        let presented = composer.present(imageData: data) {
            isComposing = false
        }
        if !presented { isComposing = false }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func isScrolling(_ scene: ShoutScene) -> Bool {
        guard scene.sizing == .scroll else { return false }
        return ShoutRenderer.marqueeMotion(for: scene.text, font: scene.font, canvas: ShoutCanvas(size: screenSize)).scrolls
    }
}

/// Accessibility identifiers the UI tests use (repeated there as strings).
enum ShoutAccessibilityID {
    static let text = "shout.text"
    static let back = "shout.back"
    static let doubleBack = "shout.doubleBack"
    static let share = "shout.share"
    static let savedNote = "shout.saved"
}

/// The brief confirmation after Save to Camera Roll: a dark capsule near the bottom that
/// fades away after a couple of seconds. VoiceOver announces the same words.
private struct SavedNote: View {
    static let text = "Saved to Photos"

    var body: some View {
        Text(Self.text)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.black.opacity(0.75)))
            .accessibilityIdentifier(ShoutAccessibilityID.savedNote)
    }
}

/// Texture and text at one size: the renderer's image, plus the moving marquee in scroll mode.
private struct ShoutCanvasView: View {
    let scene: ShoutScene
    let size: CGSize
    let displayScale: CGFloat
    let cache: ShoutImageCache

    var body: some View {
        if size.width > 0, size.height > 0 {
            ZStack(alignment: .topLeading) {
                Image(uiImage: cache.image(
                    of: scene,
                    size: size,
                    scale: displayScale,
                    content: scene.sizing == .scroll ? .backgroundOnly : .full
                ))
                .resizable()
                .frame(width: size.width, height: size.height)
                .accessibilityHidden(true)
                if scene.sizing == .scroll {
                    ShoutMarquee(text: scene.text, font: scene.font, size: size)
                        .frame(width: size.width, height: size.height)
                }
            }
        }
    }
}

/// Keeps the last rendered image, so redrawing the view (the toolbar toggling, say) does not
/// re-render the shout.
@MainActor
final class ShoutImageCache {
    private struct Key: Equatable {
        let scene: ShoutScene
        let size: CGSize
        let scale: CGFloat
        let content: ShoutRenderer.Content
    }

    private var key: Key?
    private var image: UIImage?

    func image(of scene: ShoutScene, size: CGSize, scale: CGFloat, content: ShoutRenderer.Content) -> UIImage {
        let key = Key(scene: scene, size: size, scale: scale, content: content)
        if key == self.key, let image { return image }
        let rendered = ShoutRenderer.image(of: scene, size: size, scale: scale, content: content)
        self.key = key
        image = rendered
        return rendered
    }
}

/// The toolbar (SPEC.md 7, PLAN rulings 4 and 7): the original's black bar art across the top
/// edge to edge, its buttons inside the safe area, so nothing sits under the Dynamic Island or
/// the sensor housing. Double back, then back, at the leading end; export (1.0.1's share
/// button) at the trailing end, which opens the "Export Shout" sheet.
struct ShoutToolbar: View {
    static let height: CGFloat = 44
    static let tapSize: CGFloat = 44

    let onDoubleBack: () -> Void
    let onBack: () -> Void
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onDoubleBack) { Text("Back 2 Steps") }
                .buttonStyle(ImageButtonStyle(up: .doubleBackUp, down: .doubleBackDown, minimumTapSize: Self.tapSize))
                .accessibilityLabel("Back 2 Steps")
                .accessibilityHint("Returns to the options.")
                .accessibilityIdentifier(ShoutAccessibilityID.doubleBack)
            Button(action: onBack) { Text("Back 1 Step") }
                .buttonStyle(ImageButtonStyle(up: .back2Up, down: .back2Down, minimumTapSize: Self.tapSize))
                .accessibilityLabel("Back 1 Step")
                .accessibilityHint("Returns to editing your message.")
                .accessibilityIdentifier(ShoutAccessibilityID.back)
            Spacer(minLength: 0)
            Button(action: onExport) { Text("Export Shout") }
                .buttonStyle(ImageButtonStyle(up: .shareUp, down: .shareDown, minimumTapSize: Self.tapSize))
                .accessibilityLabel("Export Shout")
                .accessibilityHint("Saves the shout to your photos or sends it in a message.")
                .accessibilityIdentifier(ShoutAccessibilityID.share)
        }
        .padding(.horizontal, 6)
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .background {
            Image(decorative: ChromeImage.shoutToolbar.rawValue)
                .resizable()
                .ignoresSafeArea(edges: [.horizontal, .top])
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// The scrolling marquee on screen. It draws with `ShoutRenderer.drawMarquee`, the same code
/// an export uses, once per display frame while the text is wider than the screen.
private struct ShoutMarquee: UIViewRepresentable {
    let text: String
    let font: ShoutFont
    let size: CGSize

    func makeUIView(context: Context) -> MarqueeView {
        MarqueeView()
    }

    func updateUIView(_ view: MarqueeView, context: Context) {
        view.configure(text: text, font: font, size: size)
    }
}

/// Redraws itself every frame from a display link while its text scrolls. The time starts when
/// the view first has text and a window; changing the text or font starts it again.
final class MarqueeView: UIView {
    private var text = ""
    private var font: ShoutFont = .pencil
    private var canvas = ShoutCanvas(size: .zero)
    private var startTime: CFTimeInterval?
    private var displayLink: CADisplayLink?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        // The whole marquee at 0.75 (SPEC 6.3); the drawing itself is opaque ink.
        alpha = ShoutCanvas.marqueeAlpha
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func configure(text: String, font: ShoutFont, size: CGSize) {
        let textChanged = text != self.text || font != self.font
        let sizeChanged = size != canvas.size
        guard textChanged || sizeChanged else { return }
        self.text = text
        self.font = font
        canvas = ShoutCanvas(size: size)
        if textChanged { startTime = nil }
        updateDisplayLink()
        setNeedsDisplay()
    }

    /// Seconds since the marquee started, 0 before it has.
    var elapsed: TimeInterval {
        guard let startTime else { return 0 }
        return CACurrentMediaTime() - startTime
    }

    var scrolls: Bool {
        ShoutRenderer.marqueeMotion(for: text, font: font, canvas: canvas).scrolls
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateDisplayLink()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        ShoutRenderer.drawMarquee(text, font: font, canvas: canvas, time: elapsed, appliesAlpha: false, context: context)
    }

    private func updateDisplayLink() {
        let shouldRun = window != nil && scrolls
        if shouldRun {
            if startTime == nil { startTime = CACurrentMediaTime() }
            guard displayLink == nil else { return }
            let link = CADisplayLink(target: DisplayLinkTarget(view: self), selector: #selector(DisplayLinkTarget.step))
            // 60 frames a second is smooth for 90 pt/s and halves the drawing on ProMotion screens.
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            link.add(to: .main, forMode: .common)
            displayLink = link
        } else {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    /// The whole view: script glyphs (Kristi's tails and loops) reach well outside the line's
    /// box, and redrawing only that band left stale pieces of them behind.
    fileprivate func step() {
        setNeedsDisplay()
    }
}

/// Holds the marquee weakly, so the display link (which retains its target) does not keep it.
@MainActor
private final class DisplayLinkTarget: NSObject {
    weak var view: MarqueeView?

    init(view: MarqueeView) {
        self.view = view
    }

    @objc func step() {
        view?.step()
    }
}
