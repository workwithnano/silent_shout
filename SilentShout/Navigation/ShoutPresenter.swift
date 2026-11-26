import SwiftUI
import UIKit

/// Presents the shout the way the original did: a full-screen modal with a cross-dissolve
/// (`UIModalTransitionStyleCrossDissolve`), over whatever is on screen, while `isPresented`
/// is true, and dismisses it with the same dissolve when it turns false.
///
/// SwiftUI's `fullScreenCover` only slides up, so this presents a `ShoutHostingController`
/// through UIKit. Being a separate view controller also lets phase 4 give the shout its own
/// landscape orientations while Editing underneath stays portrait.
struct ShoutPresenter<Content: View>: UIViewControllerRepresentable {
    let isPresented: Bool
    /// True as the shout is presented, false once its dismissal has completed.
    let onScreenChange: (Bool) -> Void
    @ViewBuilder let content: () -> Content

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        let anchor = UIViewController()
        anchor.view.isUserInteractionEnabled = false
        return anchor
    }

    func updateUIViewController(_ anchor: UIViewController, context: Context) {
        let coordinator = context.coordinator
        if isPresented {
            if let shout = coordinator.shout {
                shout.rootView = AnyView(content())
            } else {
                let shout = ShoutHostingController(rootView: AnyView(content()))
                coordinator.shout = shout
                let onScreenChange = onScreenChange
                // Present after this SwiftUI update pass, from the topmost controller.
                Task { @MainActor [weak anchor] in
                    guard let anchor, coordinator.shout === shout else { return }
                    var top = anchor.view.window?.rootViewController
                    while let presented = top?.presentedViewController { top = presented }
                    guard let top else { return }
                    onScreenChange(true)
                    top.present(shout, animated: true)
                }
            }
        } else if let shout = coordinator.shout {
            coordinator.shout = nil
            let onScreenChange = onScreenChange
            Task { @MainActor in
                guard let presenter = shout.presentingViewController else {
                    onScreenChange(false)
                    return
                }
                presenter.dismiss(animated: true) {
                    onScreenChange(false)
                }
            }
        }
    }

    @MainActor
    final class Coordinator {
        var shout: ShoutHostingController?
    }
}

/// The shout's view controller: full screen, cross-dissolve, status bar hidden (SPEC.md
/// section 2.3). Phase 4 adds the landscape orientations here.
final class ShoutHostingController: UIHostingController<AnyView> {
    override init(rootView: AnyView) {
        super.init(rootView: rootView)
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var prefersStatusBarHidden: Bool { true }
}
