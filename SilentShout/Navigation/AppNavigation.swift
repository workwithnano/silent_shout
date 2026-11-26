import Combine
import SwiftUI
import UIKit

/// Screens pushed on top of Options (the root).
enum AppRoute: Hashable, Sendable {
    case editing
}

/// Where the user is, shared through the environment so any screen can move them: the
/// navigation stack's path (Options pushes Editing; the shout's double-back pops straight
/// to Options), whether the shout is up, and the physical device orientation.
@Observable
@MainActor
final class AppNavigation {
    var path: [AppRoute] = []

    /// True from the moment a shout starts until it is dismissed: the original's `shouting`
    /// flag. While it is set, further Done presses and rotations do not start a second shout.
    private(set) var isShouting = false

    /// True while the shout's view controller is on screen, including both cross-dissolves:
    /// set when it is presented, cleared when its dismissal has finished. Editing waits for
    /// this to clear before taking the keyboard back, because a field under a full-screen
    /// presentation (or one still dissolving away) cannot become first responder.
    private(set) var isShoutOnScreen = false

    /// True once the shout's presentation (cross-dissolve and rotation) has finished, until it
    /// starts leaving. UIKit ignores touches while a presentation runs, so the UI tests wait for
    /// this (through `ShoutStateProbe`) before tapping the shout.
    private(set) var isShoutPresented = false

    /// The physical orientation of the phone, from `UIDevice` notifications (see `RootView`).
    /// The interface stays portrait-locked on Options and Editing, as in the original, so this
    /// is how Editing sees the phone turned on its side. The shout watches it too
    /// (turning back to portrait leaves the shout).
    private(set) var deviceOrientation: UIDeviceOrientation = .unknown

    /// Set by double-back: the shout is dismissing and Options comes next, so Editing must not
    /// take the keyboard back in between. Cleared the next time Editing is shown.
    private(set) var isReturningToOptions = false

    /// True while something is presented over the shout (the export sheet, a save in progress
    /// or its alert, the Messages composer). Turning the phone upright does not leave the shout
    /// meanwhile; the rule is checked again when the cover goes (`ShoutLeaveRule`).
    private(set) var isShoutCovered = false

    /// Decides when turning the phone upright leaves the shout (see `ShoutLeaveRule`).
    private var leaveRule: ShoutLeaveRule?

    var isShowingEditing: Bool { path.last == .editing }

    func showEditing() {
        isReturningToOptions = false
        path.append(.editing)
    }

    func popToOptions() {
        path.removeAll()
    }

    func pop() {
        _ = path.popLast()
    }

    /// The single entry point for starting the shout (Done key or rotation on Editing).
    /// Callers save the text first (PLAN ruling 9). Presents the shout full screen with a
    /// cross-dissolve (`ShoutPresenter` in `RootView`). Does nothing, and returns false, if a
    /// shout is already up or Editing is not the visible screen (the original's
    /// `visibleViewController != NULL` check).
    @discardableResult
    func startShout() -> Bool {
        guard !isShouting, !isShoutOnScreen, isShowingEditing else { return false }
        leaveRule = ShoutLeaveRule(startOrientation: deviceOrientation)
        isShoutCovered = false
        isShouting = true
        return true
    }

    /// Dismisses the shout with a cross-dissolve. Back (one step) returns to Editing, which puts
    /// its saved text back in the field and the keyboard back up. Double-back
    /// (`returningToOptions`) pops Editing once the dismissal has finished, landing on Options,
    /// as the original popped in the dismissal's completion.
    func endShout(returningToOptions: Bool = false) {
        guard isShouting else { return }
        leaveRule = nil
        isShoutCovered = false
        if returningToOptions { isReturningToOptions = true }
        isShoutPresented = false
        isShouting = false
    }

    /// Called by `ShoutPresenter` as the shout's view controller is presented and once its
    /// dismissal has completed.
    func shoutPresentationDidChange(onScreen: Bool) {
        isShoutOnScreen = onScreen
        if !onScreen { isShoutPresented = false }
        if !onScreen, isReturningToOptions, !isShouting {
            popToOptions()
        }
    }

    /// Called by `ShoutPresenter` when the presentation's animation has completed.
    func shoutDidFinishPresenting() {
        if isShouting { isShoutPresented = true }
    }

    /// Stores the phone's orientation and, while the shout is up, leaves it when the phone is
    /// turned upright (the original's `didRotate:` on the shout, with `ShoutLeaveRule`).
    func deviceOrientationDidChange(_ orientation: UIDeviceOrientation) {
        deviceOrientation = orientation
        guard isShouting, var rule = leaveRule else { return }
        let leaves = rule.shouldLeave(after: orientation)
        leaveRule = rule
        if leaves, !isShoutCovered {
            endShout()
        }
    }

    /// Called by the shout as something is presented over it and when that has gone. On
    /// uncovering, the leave rule is applied to the phone's orientation now: turned upright
    /// (after having been on its side) while the composer was up, the shout leaves as it closes.
    func setShoutCovered(_ covered: Bool) {
        guard isShouting, covered != isShoutCovered else { return }
        isShoutCovered = covered
        if !covered, leaveRule?.leavesOnUncover(currentOrientation: deviceOrientation) == true {
            endShout()
        }
    }
}

/// Which physical orientations start or leave the shout (SPEC.md section 1). Face up, face
/// down, upside down and unknown do nothing on any screen.
enum ShoutOrientationRule {
    /// Turning the phone to either landscape on Editing starts the shout.
    static func startsShout(_ orientation: UIDeviceOrientation) -> Bool {
        orientation == .landscapeLeft || orientation == .landscapeRight
    }

    /// Turning it back upright on the shout returns to Editing, subject to `ShoutLeaveRule`.
    static func leavesShout(_ orientation: UIDeviceOrientation) -> Bool {
        orientation == .portrait
    }

    /// The interface orientation the shout is presented in: upright for the landscape the
    /// phone is held in (device landscape left is interface landscape right, and the other way
    /// round), or landscape right when the phone is upright (the Done key), as the original
    /// forced the status bar to `UIInterfaceOrientationLandscapeRight`.
    static func presentationOrientation(for device: UIDeviceOrientation) -> UIInterfaceOrientation {
        switch device {
        case .landscapeLeft: .landscapeRight
        case .landscapeRight: .landscapeLeft
        default: .landscapeRight
        }
    }
}

/// When the shout leaves because the phone is turned upright (SPEC.md section 1, "Leaving the
/// Shout"), with the Done-key case handled:
///
/// The shout leaves on a device-orientation change to portrait **only after the phone has been
/// seen in a landscape orientation since the shout started** (it was landscape when the shout
/// started, or has turned to either landscape since). A shout started by the Done key with the
/// phone upright therefore stays up until the phone has been turned to landscape and back.
/// Face up, face down, upside down and unknown neither leave nor reset that memory. The
/// toolbar's back buttons leave at any time.
///
/// While something is presented over the shout (the export sheet, the save alert, the
/// Messages composer), turning upright does not leave; when it is dismissed the rule is applied
/// to the orientation the phone is in then (`leavesOnUncover`).
struct ShoutLeaveRule: Equatable, Sendable {
    private(set) var hasBeenLandscape: Bool

    init(startOrientation: UIDeviceOrientation) {
        hasBeenLandscape = ShoutOrientationRule.startsShout(startOrientation)
    }

    /// Feeds one orientation change; true when the shout should leave.
    mutating func shouldLeave(after orientation: UIDeviceOrientation) -> Bool {
        if ShoutOrientationRule.startsShout(orientation) {
            hasBeenLandscape = true
            return false
        }
        return ShoutOrientationRule.leavesShout(orientation) && hasBeenLandscape
    }

    /// Whether the shout should leave when whatever covered it goes, with the phone now in
    /// `currentOrientation`: upright, after having been on its side. While covered, changes
    /// are still fed to `shouldLeave(after:)` so the landscape memory stays current.
    func leavesOnUncover(currentOrientation: UIDeviceOrientation) -> Bool {
        ShoutOrientationRule.leavesShout(currentOrientation) && hasBeenLandscape
    }
}

/// Which orientations the app currently allows: portrait for Options and Editing (SPEC.md
/// section 1), landscape while the shout is up. The shout's view controller reports this same
/// mask as its supported orientations (`ShoutHostingController`), so the window's mask and the
/// top controller's never disagree, which UIKit treats as a fatal error.
@MainActor
enum OrientationLock {
    static private(set) var mask: UIInterfaceOrientationMask = .portrait

    /// Changes the mask and asks every controller to re-read it, which rotates the interface
    /// if its current orientation is no longer allowed.
    static func set(_ newMask: UIInterfaceOrientationMask) {
        guard newMask != mask else { return }
        mask = newMask
        updateControllers()
    }

    /// Changes the mask without asking anything to rotate now. The shout's presentation uses
    /// this: the presentation itself rotates to the shout's orientation, so Editing underneath
    /// never turns on its own first.
    static func setQuietly(_ newMask: UIInterfaceOrientationMask) {
        mask = newMask
    }

    private static func updateControllers() {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                var controller = window.rootViewController
                while let current = controller {
                    current.setNeedsUpdateOfSupportedInterfaceOrientations()
                    controller = current.presentedViewController
                }
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // The original turned these on in Editing's viewDidLoad; they are cheap, so they run
        // for the app's lifetime and `RootView` forwards them to `AppNavigation`.
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationLock.mask
    }
}

/// The app's root: a navigation stack with the system bar hidden, as the original hid
/// `UINavigationController`'s bar, starting on Options. The shout is presented over it.
struct RootView: View {
    @Environment(ShoutSettings.self) private var settings
    @State private var navigation = AppNavigation()

    var body: some View {
        NavigationStack(path: $navigation.path) {
            OptionsView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .editing: EditingView()
                    }
                }
        }
        .background {
            ShoutPresenter(
                isPresented: navigation.isShouting,
                onScreenChange: { navigation.shoutPresentationDidChange(onScreen: $0) },
                onPresented: { navigation.shoutDidFinishPresenting() }
            ) {
                ShoutView()
                    .environment(settings)
                    .environment(navigation)
                    .preferredColorScheme(.dark)
            }
        }
        // The one place device orientation changes enter the app.
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            navigation.deviceOrientationDidChange(UIDevice.current.orientation)
        }
        .environment(navigation)
        .preferredColorScheme(.dark)
    }
}
