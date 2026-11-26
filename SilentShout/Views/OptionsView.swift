import PhotosUI
import SwiftUI
import UIKit

/// The Options (main) screen, SPEC.md section 2.1: the three option carousels on the tiled
/// main background, the help button and overlay, and the Next button that opens Editing.
struct OptionsView: View {
    @Environment(ShoutSettings.self) private var settings
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.displayScale) private var displayScale
    @State private var showsHelp = false
    /// The longest screen edge in points, for the photo's size limit.
    @State private var screenLength: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let layout = OptionsLayout(size: proxy.size)
            ZStack(alignment: .topLeading) {
                block(.font, layout: layout)
                block(.texture, layout: layout)
                block(.sizing, layout: layout)
                helpButton.offset(origin: layout.helpButtonFrame.origin)
                nextButton.offset(origin: layout.nextButtonFrame.origin)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .background { MainBackground() }
        .background {
            GeometryReader { full in
                Color.clear.onAppear { screenLength = max(full.size.width, full.size.height) }
            }
            .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { OrientationLock.set(.portrait) }
    }

    // MARK: Blocks

    private func block(_ block: OptionBlock, layout: OptionsLayout) -> some View {
        let frame = layout.blockFrame(block)
        return ZStack(alignment: .topLeading) {
            carousel(block, layout: layout)
                .offset(origin: layout.carouselFrameInBlock.origin)
            PageDots(count: optionCount(block), current: dotIndex(block))
                .frame(width: frame.width)
                .offset(y: OptionsLayout.pageDotsCenterY - 6.5 / 2)
            if showsHelp {
                HelpBubble(block: block)
                    .offset(origin: layout.bubbleFrameInBlock(block).origin)
                    .transition(.opacity)
            }
        }
        .frame(width: frame.width, height: frame.height, alignment: .topLeading)
        .offset(origin: frame.origin)
    }

    @ViewBuilder
    private func carousel(_ block: OptionBlock, layout: OptionsLayout) -> some View {
        @Bindable var settings = settings
        let width = layout.size.width
        switch block {
        case .font:
            OptionCarousel(
                title: "Writing tool",
                identifier: OptionsAccessibilityID.carousel(block),
                pageWidth: width,
                selection: $settings.font,
                accessibilityName: \.accessibilityName
            ) { font in
                Image(font.carouselImageName)
            }
        case .texture:
            OptionCarousel(
                title: "Background",
                identifier: OptionsAccessibilityID.carousel(block),
                pageWidth: width,
                selection: $settings.texture,
                restingPage: settings.usesPhoto ? ShoutTexture.allCases.count - 1 : nil,
                valueOverride: settings.usesPhoto ? CameraEntry.photoValue : nil,
                onUserChoice: { settings.useTexture($0) },
                accessibilityName: \.accessibilityName
            ) { texture in
                Image(texture.carouselImageName)
                    .opacity(settings.usesPhoto ? 0.4 : 1)
            } trailing: {
                // 1.0.1's camera entry: after the last texture and not a page. In 1.0.1 it sat
                // a whole art margin beyond the scrollable width, out of reach; here it sits in
                // the last page's trailing margin, beside the cardboard (QUESTIONS.md).
                let side = CameraEntry.side(pageWidth: width)
                Color.clear
                    .frame(width: 0, height: OptionsLayout.carouselHeight)
                    .overlay(alignment: .trailing) {
                        CameraEntry(maxPixelLength: PhotoProcessing.maxPixelLength(
                            screenSize: CGSize(width: screenLength, height: screenLength),
                            scale: displayScale
                        ))
                        .frame(width: side, height: side)
                        .padding(.trailing, CameraEntry.trailingInset(pageWidth: width, side: side))
                        .fixedSize()
                    }
            }
        case .sizing:
            OptionCarousel(
                title: "Presentation",
                identifier: OptionsAccessibilityID.carousel(block),
                pageWidth: width,
                selection: $settings.sizing,
                accessibilityName: \.accessibilityName
            ) { sizing in
                SizingAnimationView(sizing: sizing)
            }
        }
    }

    private func optionCount(_ block: OptionBlock) -> Int {
        switch block {
        case .font: ShoutFont.allCases.count
        case .texture: ShoutTexture.allCases.count
        case .sizing: ShoutSizing.allCases.count
        }
    }

    /// The lit page dot; none for the texture carousel while the photo is the background,
    /// since the camera entry has no dot.
    private func dotIndex(_ block: OptionBlock) -> Int {
        switch block {
        case .font: settings.font.rawValue
        case .texture: settings.usesPhoto ? -1 : settings.texture.rawValue
        case .sizing: settings.sizing.rawValue
        }
    }

    // MARK: Buttons

    private var helpButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.5)) { showsHelp.toggle() }
        } label: {
            Text("Help")
        }
        .buttonStyle(ImageButtonStyle(up: .helpUp, down: .helpDown, selected: .helpActive, isSelected: showsHelp))
        .frame(width: OptionsLayout.buttonSize, height: OptionsLayout.buttonSize)
        .accessibilityLabel("Help")
        .accessibilityAddTraits(showsHelp ? .isSelected : [])
        .accessibilityIdentifier(OptionsAccessibilityID.help)
    }

    private var nextButton: some View {
        Button {
            navigation.showEditing()
        } label: {
            Text("Shout")
        }
        .buttonStyle(ImageButtonStyle(up: .nextUp, down: .nextDown))
        .frame(width: OptionsLayout.buttonSize, height: OptionsLayout.buttonSize)
        .accessibilityLabel("Shout")
        .accessibilityIdentifier(OptionsAccessibilityID.next)
    }
}

/// Accessibility identifiers the UI tests use (they repeat these strings, since a UI test
/// bundle cannot import the app).
enum OptionsAccessibilityID {
    static let help = "options.help"
    static let next = "options.next"
    static let camera = "options.camera"

    static func carousel(_ block: OptionBlock) -> String {
        "options.carousel.\(block.key)"
    }

    static func bubble(_ block: OptionBlock) -> String {
        "options.help.bubble.\(block.key)"
    }
}

extension OptionBlock {
    /// The UserDefaults key the block's carousel stores.
    var key: String {
        switch self {
        case .font: ShoutSettings.Key.font
        case .texture: ShoutSettings.Key.texture
        case .sizing: ShoutSettings.Key.lettering
        }
    }
}

/// A help bubble (SPEC.md section 8), with the words printed on its art as its label.
struct HelpBubble: View {
    let block: OptionBlock

    var body: some View {
        Image(image.rawValue)
            .accessibilityLabel(label)
            .accessibilityIdentifier(OptionsAccessibilityID.bubble(block))
            .allowsHitTesting(false)
    }

    private var image: ChromeImage {
        switch block {
        case .font: .helpBubbleWritingTool
        case .texture: .helpBubbleBackground
        case .sizing: .helpBubblePresentation
        }
    }

    private var label: String {
        switch block {
        case .font: "Writing Tool"
        case .texture: "Background"
        case .sizing: "Presentation"
        }
    }
}

/// `bkgrnd_main` tiled behind everything, as the original's pattern colour, under the
/// status bar and home indicator too.
///
/// The 320x461 art was never made to tile (on the original screen one copy covered the
/// 320x460 content area), so plain repetition shows hard seams on today's wider and taller
/// screens. Alternate copies are mirrored instead, which keeps the art at its own size and
/// makes every edge meet its own reflection. Recorded in QUESTIONS.md.
struct MainBackground: View {
    var body: some View {
        Group {
            if let tile = MirroredTile.mainBackground {
                Image(uiImage: tile).resizable(resizingMode: .tile)
            } else {
                Image(ChromeImage.mainBackground.rawValue).resizable(resizingMode: .tile)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

@MainActor
enum MirroredTile {
    /// A 2x2 tile of the background: original, mirrored left-right, mirrored top-bottom, both.
    static let mainBackground: UIImage? = make(from: ChromeImage.mainBackground.rawValue)

    static func make(from name: String) -> UIImage? {
        guard let original = UIImage(named: name), let cgImage = original.cgImage else { return nil }
        // The art's top 1.5 pt and bottom 2 pt are a dark/light edge line (a scan or export
        // border) that shows as a stripe once tiles meet; trim it before mirroring.
        let scale = original.scale
        let crop = CGRect(
            x: 0,
            y: (1.5 * scale).rounded(),
            width: CGFloat(cgImage.width),
            height: (457 * scale).rounded()
        )
        guard let trimmed = cgImage.cropping(to: crop) else { return nil }
        let image = UIImage(cgImage: trimmed, scale: scale, orientation: .up)
        let size = image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size.width * 2, height: size.height * 2), format: format)
        return renderer.image { context in
            let cg = context.cgContext
            for row in 0..<2 {
                for column in 0..<2 {
                    cg.saveGState()
                    cg.translateBy(x: size.width * CGFloat(column + (column == 1 ? 1 : 0)),
                                   y: size.height * CGFloat(row + (row == 1 ? 1 : 0)))
                    cg.scaleBy(x: column == 1 ? -1 : 1, y: row == 1 ? -1 : 1)
                    image.draw(in: CGRect(origin: .zero, size: size))
                    cg.restoreGState()
                }
            }
        }
    }
}

private extension View {
    func offset(origin: CGPoint) -> some View {
        offset(x: origin.x, y: origin.y)
    }
}
