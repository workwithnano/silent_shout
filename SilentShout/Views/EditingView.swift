import SwiftUI
import UIKit

/// The Editing screen, SPEC.md section 2.2: the live preview card on the chosen texture, and
/// the text bar sitting on the keyboard, which is up for as long as the screen shows.
///
/// The field's text lives in `draft` and is written to `ShoutSettings.text` on every change
/// of screen (PLAN ruling 9): back to Options, the shout starting (Done or rotation), and the
/// app leaving the foreground.
struct EditingView: View {
    @Environment(ShoutSettings.self) private var settings
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.scenePhase) private var scenePhase

    @State private var draft = ""
    /// Set when the back button is tapped, so the keyboard goes down with the pop.
    @State private var isLeaving = false

    var body: some View {
        GeometryReader { proxy in
            let layout = EditingLayout(size: proxy.size)
            ZStack(alignment: .topLeading) {
                PreviewCard(text: draft, font: settings.font, texture: settings.texture, photo: settings.activePhoto, layout: layout)
                    .frame(width: layout.cardFrame.width, height: layout.cardFrame.height)
                    .offset(x: layout.cardFrame.minX, y: layout.cardFrame.minY)
                TextBar(
                    layout: layout,
                    text: $draft,
                    wantsFocus: !navigation.isShouting && !navigation.isShoutOnScreen && !navigation.isReturningToOptions && !isLeaving,
                    onBack: backToOptions,
                    onDone: startShout
                )
                .frame(width: layout.barFrame.width, height: layout.barFrame.height)
                .offset(x: layout.barFrame.minX, y: layout.barFrame.minY)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .background { MainBackground() }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            OrientationLock.set(.portrait)
            isLeaving = false
            loadSavedText()
        }
        .onChange(of: navigation.isShouting) { _, shouting in
            // Back from the shout: the original re-ran its setup, reloading the saved text
            // into the field; `wantsFocus` puts the keyboard back up.
            if !shouting { loadSavedText() }
        }
        .onChange(of: navigation.deviceOrientation) { _, orientation in
            if ShoutOrientationRule.startsShout(orientation) { startShout() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, navigation.isShowingEditing { saveText() }
        }
    }

    private func loadSavedText() {
        draft = settings.text ?? ""
    }

    private func saveText() {
        if settings.text != draft { settings.text = draft }
    }

    /// Done key or rotation: save, then start the shout (guarded against a second start).
    private func startShout() {
        guard !navigation.isShouting, !navigation.isShoutOnScreen, navigation.isShowingEditing, !isLeaving else { return }
        saveText()
        navigation.startShout()
    }

    /// The text bar's toggle button: save and go back to Options without shouting.
    private func backToOptions() {
        guard !navigation.isShouting, !navigation.isShoutOnScreen, !isLeaving else { return }
        saveText()
        isLeaving = true
        navigation.pop()
    }
}

/// Accessibility identifiers the UI tests use (repeated there as strings).
enum EditingAccessibilityID {
    static let back = "editing.back"
    static let textField = "editing.textField"
    static let preview = "editing.preview"
}

/// The preview: the texture's preview art with the text fitted into the original 300x206 box
/// (`TextFitter.preview`) and drawn at the card's scale. It always uses fit-to-box, whatever
/// the presentation setting: the original's scrolling preview was never connected (SPEC 2.2).
///
/// With a camera photo as the background (phase 5) the photo aspect-fills the whole card
/// instead of the texture's preview art; the text is drawn the same way on top.
struct PreviewCard: View {
    let text: String
    let font: ShoutFont
    let texture: ShoutTexture
    var photo: UIImage? = nil
    let layout: EditingLayout

    var body: some View {
        let art = layout.previewArtFrameInCard
        let label = layout.labelFrameInCard
        let fitted = TextFitter.preview.fontSize(for: text, fontName: font.fontName)
        ZStack(alignment: .topLeading) {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: layout.cardFrame.width, height: layout.cardFrame.height)
                    .clipped()
            } else {
                Image(texture.previewImageName)
                    .resizable()
                    .frame(width: art.width, height: art.height)
                    .offset(x: art.minX, y: art.minY)
            }
            PreviewLabel(
                text: text,
                font: font.uiFont(size: fitted * layout.cardScale) ?? .systemFont(ofSize: fitted * layout.cardScale),
                color: font.ink.uiColor
            )
            .frame(width: label.width, height: label.height)
            .offset(x: label.minX, y: label.minY)
        }
        .frame(width: layout.cardFrame.width, height: layout.cardFrame.height, alignment: .topLeading)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview")
        .accessibilityValue(text)
        .accessibilityIdentifier(EditingAccessibilityID.preview)
    }
}

/// The preview's text, a `UILabel` like the original's: centred, word wrap, any number of
/// lines, vertically centred, clipped. (A SwiftUI `Text` would truncate with an ellipsis
/// where the original simply clipped.)
struct PreviewLabel: UIViewRepresentable {
    let text: String
    let font: UIFont
    let color: UIColor

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.lineBreakMode = .byWordWrapping
        label.clipsToBounds = true
        label.backgroundColor = .clear
        label.isAccessibilityElement = false
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .vertical)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.text = text
        label.font = font
        label.textColor = color
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }
}

/// The text bar: `toolbar_Textfield` art, the back (toggle) button, and the field on its
/// rounded `textfield` background.
struct TextBar: View {
    let layout: EditingLayout
    @Binding var text: String
    let wantsFocus: Bool
    let onBack: () -> Void
    let onDone: () -> Void

    var body: some View {
        let back = layout.backButtonFrameInBar
        let fieldBackground = layout.fieldBackgroundFrameInBar
        let field = layout.textFieldFrameInBar
        let cap = EditingLayout.fieldCapInset
        ZStack(alignment: .topLeading) {
            Image(ChromeImage.textBar.rawValue)
                .resizable(resizingMode: .tile)
                .frame(width: layout.barFrame.width, height: layout.barFrame.height)
                .accessibilityHidden(true)
            Button(action: onBack) {
                Text("Back")
            }
            .buttonStyle(ImageButtonStyle(up: .backUp, down: .backDown))
            .frame(width: back.width, height: back.height)
            .contentShape(Rectangle())
            .offset(x: back.minX, y: back.minY)
            .accessibilityLabel("Back")
            .accessibilityHint("Saves your message and returns to the options.")
            .accessibilityIdentifier(EditingAccessibilityID.back)
            Image(ChromeImage.textField.rawValue)
                .resizable(capInsets: EdgeInsets(top: 0, leading: cap, bottom: 0, trailing: cap), resizingMode: .stretch)
                .frame(width: fieldBackground.width, height: fieldBackground.height)
                .offset(x: fieldBackground.minX, y: fieldBackground.minY)
                .accessibilityHidden(true)
            ShoutTextField(
                text: $text,
                wantsFocus: wantsFocus,
                accessibilityLabel: "Message",
                accessibilityIdentifier: EditingAccessibilityID.textField,
                onDone: onDone
            )
            .frame(width: field.width, height: field.height)
            .offset(x: field.minX, y: field.minY)
        }
        .frame(width: layout.barFrame.width, height: layout.barFrame.height, alignment: .topLeading)
    }
}
