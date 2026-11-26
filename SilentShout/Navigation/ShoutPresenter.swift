import SwiftUI
import UIKit

/// Presents the shout the way the original did: a full-screen modal with a cross-dissolve
/// (`UIModalTransitionStyleCrossDissolve`), over whatever is on screen, while `isPresented`
/// is true, and dismisses it with the same dissolve when it turns false.
///
/// SwiftUI's `fullScreenCover` only slides up, so this presents a `ShoutHostingController`
/// through UIKit. Being a separate view controller also gives the shout its own landscape
/// orientations while Editing underneath stays portrait.
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
                let orientation = ShoutOrientationRule.presentationOrientation(for: UIDevice.current.orientation)
                let shout = ShoutHostingController(rootView: AnyView(content()), orientation: orientation)
                coordinator.shout = shout
                let onScreenChange = onScreenChange
                // Present after this SwiftUI update pass, from the topmost controller.
                Task { @MainActor [weak anchor] in
                    guard let anchor, coordinator.shout === shout else { return }
                    var top = anchor.view.window?.rootViewController
                    while let presented = top?.presentedViewController { top = presented }
                    guard let top else { return }
                    onScreenChange(true)
                    // Landscape only from here on (PLAN ruling 2). Set quietly, in the same
                    // turn as the presentation, so the presentation does the rotating and
                    // Editing does not turn first.
                    OrientationLock.setQuietly(.landscape)
                    top.present(shout, animated: true)
                }
            }
        } else if let shout = coordinator.shout {
            coordinator.shout = nil
            let onScreenChange = onScreenChange
            Task { @MainActor in
                shout.leave {
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
/// section 2.3), landscape only, home indicator auto-hidden, screen kept awake.
///
/// Orientation: it reports `OrientationLock.mask` as its supported orientations, so the
/// window's mask and its own always agree. The presenter sets the mask to landscape as it
/// presents; the presentation rotates to `orientation` (upright for the landscape the phone
/// is held in, or landscape right from the Done key) and the system then follows the phone
/// between the two landscapes. `leave(completion:)` sets the mask back to portrait, waits for
/// that rotation, and then dissolves away, so Editing reappears upright in portrait.
final class ShoutHostingController: UIHostingController<AnyView> {
    private let presentationOrientation: UIInterfaceOrientation
    private var hasAppeared = false
    private var isLeaving = false
    private var pendingLeave: (() -> Void)?
    private var dismissAfterRotation: (() -> Void)?
    private var idleTimerWasDisabled = false

    init(rootView: AnyView, orientation: UIInterfaceOrientation) {
        presentationOrientation = orientation
        super.init(rootView: rootView)
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { OrientationLock.mask }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { presentationOrientation }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // A sign that sleeps is not much of a sign (QUESTIONS.md). Restored on the way out.
        idleTimerWasDisabled = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        hasAppeared = true
        if let pendingLeave {
            self.pendingLeave = nil
            pendingLeave()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = idleTimerWasDisabled
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.finishRotationIfLeaving()
        }
    }

    /// Every way out of the shout (back, double-back, turning upright) ends here: portrait for
    /// the rest of the app, then the cross-dissolve away. `completion` runs once the dismissal
    /// has finished. A leave requested while the shout is still dissolving in waits for it to
    /// finish appearing, since UIKit ignores a dismissal during a presentation.
    func leave(completion: @escaping () -> Void) {
        guard presentingViewController != nil else {
            OrientationLock.set(.portrait)
            completion()
            return
        }
        guard hasAppeared else {
            pendingLeave = { [weak self] in self?.leave(completion: completion) }
            return
        }
        guard !isLeaving else { return }
        isLeaving = true
        dismissAfterRotation = { [weak self] in
            guard let self else { return completion() }
            guard let presenter = self.presentingViewController else { return completion() }
            presenter.dismiss(animated: true, completion: completion)
        }
        OrientationLock.set(.portrait)
        if isPortrait {
            finishRotationIfLeaving()
        } else if let scene = view.window?.windowScene {
            // Normally the mask change above has already started the rotation; this makes sure
            // of it, and dismisses anyway if the system refuses.
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in self.finishRotationIfLeaving() }
            }
        } else {
            finishRotationIfLeaving()
        }
    }

    private var isPortrait: Bool {
        view.window?.windowScene?.effectiveGeometry.interfaceOrientation.isPortrait ?? true
    }

    private func finishRotationIfLeaving() {
        // Called from the rotation's completion, straight away when already upright, or when
        // the system refuses the rotation. Acts once.
        guard isLeaving, let dismiss = dismissAfterRotation else { return }
        dismissAfterRotation = nil
        dismiss()
    }
}
