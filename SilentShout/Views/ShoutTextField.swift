import SwiftUI
import UIKit

/// The Editing screen's text field (SPEC.md section 2.2), a `UITextField` because SwiftUI's
/// `TextField` has no clear button or keyboard appearance: Helvetica 15, black text, clear
/// button while editing, sentence capitalisation, autocorrection, dark keyboard, Done key.
///
/// `wantsFocus` keeps it first responder (the keyboard is up for as long as Editing shows):
/// it becomes first responder as soon as it is in a window, including when the screen comes
/// back from the shout. The Done key calls `onDone` and nothing else; ending editing has no
/// side effects here (the original's `flipScreen` flag existed to stop end-of-editing from
/// starting a shout; the rewrite triggers the shout and saves explicitly instead).
struct ShoutTextField: UIViewRepresentable {
    @Binding var text: String
    var wantsFocus: Bool
    var accessibilityLabel: String
    var accessibilityIdentifier: String
    var onDone: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> FocusingTextField {
        let field = FocusingTextField()
        field.font = UIFont(name: "Helvetica", size: 15) ?? .systemFont(ofSize: 15)
        field.textColor = .black
        field.backgroundColor = .clear
        field.borderStyle = .none
        field.contentVerticalAlignment = .center
        field.clearButtonMode = .whileEditing
        field.autocapitalizationType = .sentences
        field.autocorrectionType = .yes
        field.keyboardAppearance = .dark
        // The field draws on the white `textfield` art, but the app runs in dark mode, which
        // would draw the clear button light grey on white (invisible). The keyboard stays
        // dark through `keyboardAppearance`.
        field.overrideUserInterfaceStyle = .light
        field.returnKeyType = .done
        field.text = text
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.accessibilityLabel = accessibilityLabel
        field.accessibilityIdentifier = accessibilityIdentifier
        return field
    }

    func updateUIView(_ field: FocusingTextField, context: Context) {
        context.coordinator.parent = self
        // Never overwrite text that is mid-composition (marked text from a multi-stage keyboard).
        if field.text != text, field.markedTextRange == nil {
            field.text = text
        }
        field.wantsFocus = wantsFocus
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: FocusingTextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? EditingLayout.fieldHeight)
    }

    @MainActor
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ShoutTextField

        init(parent: ShoutTextField) {
            self.parent = parent
        }

        /// Every edit re-renders the preview (the original's Editing Changed action).
        @objc func editingChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldShouldClear(_ textField: UITextField) -> Bool {
            parent.text = ""
            return true
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onDone()
            return false
        }
    }
}

/// A text field that holds on to first responder while `wantsFocus` is set.
final class FocusingTextField: UITextField {
    var wantsFocus = false {
        didSet { if wantsFocus != oldValue { applyFocus() } }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyFocus()
    }

    private func applyFocus() {
        if wantsFocus {
            guard window != nil, !isFirstResponder else { return }
            // After the current layout pass, so a push or a dismissal has put the field on screen.
            Task { @MainActor [weak self] in
                guard let self, self.wantsFocus, self.window != nil, !self.isFirstResponder else { return }
                self.becomeFirstResponder()
            }
        } else if isFirstResponder {
            resignFirstResponder()
        }
    }
}
