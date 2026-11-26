import MessageUI
import UIKit

/// Presents the Messages composer with the shout attached over the shout itself, and reports
/// when it has gone again (sent, cancelled or failed), leaving the shout as it was.
@MainActor
final class MessageComposer: NSObject, MFMessageComposeViewControllerDelegate {
    private var onFinish: (() -> Void)?

    /// Presents the composer from the topmost view controller (the shout's). Returns false,
    /// presenting nothing, if there is nowhere to present from.
    @discardableResult
    func present(imageData: Data, onFinish: @escaping () -> Void) -> Bool {
        guard let top = UIApplication.shared.topViewController else { return false }
        let composer = MFMessageComposeViewController()
        composer.messageComposeDelegate = self
        composer.addAttachmentData(imageData, typeIdentifier: ShoutExport.imageTypeIdentifier, filename: ShoutExport.attachmentFileName)
        self.onFinish = onFinish
        Self.present(composer, from: top)
        return true
    }

    /// Presents once anything still dismissing from `top` (the export sheet the user just
    /// tapped) has gone, since UIKit refuses a second presentation while one is on its way out.
    private static func present(_ controller: UIViewController, from top: UIViewController) {
        if let leaving = top.presentedViewController, leaving.isBeingDismissed {
            if let coordinator = leaving.transitionCoordinator {
                coordinator.animate(alongsideTransition: nil) { _ in
                    present(controller, from: top)
                }
            } else {
                Task { @MainActor in present(controller, from: top) }
            }
            return
        }
        top.present(controller, animated: true)
    }

    nonisolated func messageComposeViewController(
        _ controller: MFMessageComposeViewController,
        didFinishWith result: MessageComposeResult
    ) {
        MainActor.assumeIsolated {
            controller.dismiss(animated: true) { [weak self] in
                let onFinish = self?.onFinish
                self?.onFinish = nil
                onFinish?()
            }
        }
    }
}

extension UIApplication {
    /// The view controller at the top of the foreground window's presentation chain.
    var topViewController: UIViewController? {
        let scenes = connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}

/// The "Export Shout" sheet as a UIKit action sheet, the direct successor of the original's
/// `UIActionSheet`: title, the actions in order, and Cancel. A SwiftUI `confirmationDialog` on
/// iOS 26 presents as a popover and leaves Cancel out; this keeps the original's three rows.
@MainActor
enum ExportSheet {
    static let title = "Export Shout"

    /// Presents the sheet from the topmost view controller (the shout's, in landscape).
    /// `onChoice` gets the tapped action, or nil for Cancel (or a tap outside the sheet), after
    /// the sheet has gone. Returns false if there was nowhere to present from.
    @discardableResult
    static func present(actions: [ExportAction], onChoice: @escaping (ExportAction?) -> Void) -> Bool {
        guard let top = UIApplication.shared.topViewController else { return false }
        let sheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for action in actions {
            sheet.addAction(UIAlertAction(title: action.title, style: .default) { _ in onChoice(action) })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in onChoice(nil) })
        // On iPhone no source is given: with one, iOS 26 shows the sheet as a popover by the
        // button and leaves Cancel out; without one it rises from the bottom with Cancel, as
        // the original did. (A popover needs a source, so other devices get the button's corner.)
        if top.traitCollection.userInterfaceIdiom != .phone, let popover = sheet.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.maxX - 30, y: 30, width: 1, height: 1)
        }
        top.present(sheet, animated: true)
        return true
    }
}
