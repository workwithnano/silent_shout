import SwiftUI

@main
struct SilentShoutApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var settings: ShoutSettings

    init() {
        #if DEBUG
        // UI tests launch with this argument to start from the original defaults.
        if ProcessInfo.processInfo.arguments.contains(ShoutSettings.resetLaunchArgument) {
            ShoutSettings.resetStoredOptions()
        }
        #endif
        _settings = State(initialValue: ShoutSettings())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
        }
    }
}
