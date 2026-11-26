import Combine
import SwiftUI
import UIKit

/// Screens pushed on top of Options (the root).
enum AppRoute: Hashable, Sendable {
    case editing
}

/// Where the user is, shared through the environment so any screen can move them: the
/// navigation stack's path (Options pushes Editing; phase 4's double-back pops straight to
/// Options), whether the shout is up, and the physical device orientation.
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

    /// The physical orientation of the phone, from `UIDevice` notifications (see `RootView`).
    /// The interface stays portrait-locked on Options and Editing, as in the original, so this
    /// is how Editing sees the phone turned on its side. Phase 4's shout screen watches it too
    /// (turning back to portrait leaves the shout).
    private(set) var deviceOrientation: UIDeviceOrientation = .unknown

    var isShowingEditing: Bool { path.last == .editing }

    func showEditing() {
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
        isShouting = true
        return true
    }

    /// Dismisses the shout with a cross-dissolve, back to Editing, which puts its saved text
    /// back in the field and the keyboard back up.
    func endShout() {
        isShouting = false
    }

    /// Called by `ShoutPresenter` as the shout's view controller is presented and once its
    /// dismissal has completed.
    func shoutPresentationDidChange(onScreen: Bool) {
        isShoutOnScreen = onScreen
    }

    func deviceOrientationDidChange(_ orientation: UIDeviceOrientation) {
        deviceOrientation = orientation
    }
}

/// Which physical orientations start or leave the shout (SPEC.md section 1). Face up, face
/// down, upside down and unknown do nothing on any screen.
enum ShoutOrientationRule {
    /// Turning the phone to either landscape on Editing starts the shout.
    static func startsShout(_ orientation: UIDeviceOrientation) -> Bool {
        orientation == .landscapeLeft || orientation == .landscapeRight
    }

    /// Turning it back upright on the shout returns to Editing (phase 4 acts on this).
    static func leavesShout(_ orientation: UIDeviceOrientation) -> Bool {
        orientation == .portrait
    }
}

/// Which orientations the app currently allows. Options and Editing are portrait only
/// (SPEC.md section 1); phase 4 widens this to landscape for the shout.
@MainActor
enum OrientationLock {
    static var mask: UIInterfaceOrientationMask = .portrait

    static func set(_ newMask: UIInterfaceOrientationMask) {
        guard newMask != mask else { return }
        mask = newMask
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
                onScreenChange: { navigation.shoutPresentationDidChange(onScreen: $0) }
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
