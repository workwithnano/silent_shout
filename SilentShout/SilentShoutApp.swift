import SwiftUI

@main
struct SilentShoutApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var settings: ShoutSettings

    init() {
        #if DEBUG
        if UITestHooks.resetsSettings { ShoutSettings.resetStoredOptions() }
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
