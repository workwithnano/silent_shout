import SwiftUI
import UIKit

/// Screens pushed on top of Options (the root).
enum AppRoute: Hashable, Sendable {
    case editing
}

/// The navigation stack's path, shared through the environment so any screen can move the
/// user: Options pushes Editing; phase 4's double-back pops straight to Options.
@Observable
@MainActor
final class AppNavigation {
    var path: [AppRoute] = []

    func showEditing() {
        path.append(.editing)
    }

    func popToOptions() {
        path.removeAll()
    }

    func pop() {
        _ = path.popLast()
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
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationLock.mask
    }
}

/// The app's root: a navigation stack with the system bar hidden, as the original hid
/// `UINavigationController`'s bar, starting on Options.
struct RootView: View {
    @State private var navigation = AppNavigation()

    var body: some View {
        NavigationStack(path: $navigation.path) {
            OptionsView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .editing: EditingPlaceholderView()
                    }
                }
        }
        .environment(navigation)
        .preferredColorScheme(.dark)
    }
}
